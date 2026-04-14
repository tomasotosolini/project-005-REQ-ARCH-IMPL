require "rails_helper"

RSpec.describe "Guests::Guests", type: :request do
  let!(:user) { create(:user) }

  # Stub xl so tests never shell out to a real (or fake) xl binary.
  let(:xl_list_output) do
    <<~XL
      Name                                        ID   Mem VCPUs\tState\tTime(s)
      Domain-0                                       0  1024     1\tr-----\t55555.0
      web01                                          1   512     2\t-b----\t   99.3
      db01                                           2  1024     4\t-b----\t  420.7
    XL
  end

  before do
    allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
      { stdout: xl_list_output, stderr: "", success: true }
    )
    allow(Xen::Properties).to receive(:read_config).and_return(nil)
  end

  describe "GET /guests (root)" do
    context "when authenticated" do
      before { post login_path, params: { email: user.email, password: "password123" } }

      it "lists running guests, excluding Domain-0" do
        get guests_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("web01")
        expect(response.body).to include("db01")
        expect(response.body).not_to include("Domain-0")
      end

      it "shows running status for active guests" do
        get guests_path
        expect(response.body).to include("running")
      end

      it "includes stopped DB guests that are not running in Xen" do
        create(:guest, xen_name: "stopped01")
        get guests_path
        expect(response.body).to include("stopped01")
        expect(response.body).to include("stopped")
      end

      it "shows config details (disk, vif_bridge) when available" do
        create(:guest, xen_name: "web01")
        allow(Xen::Properties).to receive(:read_config).with("web01").and_return(
          { vcpus: 2, memory: 512, disk: "phy:/dev/vg0/web01,xvda,rw", vif_bridge: "xenbr0" }
        )
        get guests_path
        expect(response.body).to include("phy:/dev/vg0/web01,xvda,rw")
        expect(response.body).to include("xenbr0")
      end

      it "shows CPU time for running guests" do
        get guests_path
        expect(response.body).to include("99.3")
        expect(response.body).to include("420.7")
      end
    end

    context "when unauthenticated" do
      it "redirects to the login page" do
        get guests_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "GET /guests/:name" do
    context "when authenticated" do
      before { post login_path, params: { email: user.email, password: "password123" } }

      it "shows the guest detail page" do
        allow(Xen::Properties).to receive(:read_config).with("web01").and_return(
          { vcpus: 2, memory: 512, disk: nil, vif_bridge: nil }
        )
        get guest_path("web01")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("web01")
        expect(response.body).to include("512")   # memory
        expect(response.body).to include("2")     # vcpus
      end

      it "shows disk and vif_bridge config on the show page" do
        allow(Xen::Properties).to receive(:read_config).with("web01").and_return(
          { vcpus: 2, memory: 512, disk: "phy:/dev/vg0/web01,xvda,rw", vif_bridge: "xenbr0" }
        )
        get guest_path("web01")
        expect(response.body).to include("phy:/dev/vg0/web01,xvda,rw")
        expect(response.body).to include("xenbr0")
      end

      it "redirects with alert when guest is not found in Xen or DB" do
        allow(Xen::Properties).to receive(:read_config).with("nonexistent").and_return(nil)
        get guest_path("nonexistent")
        expect(response).to redirect_to(guests_path)
        follow_redirect!
        expect(response.body).to include("not found")
      end
    end

    context "when unauthenticated" do
      it "redirects to the login page" do
        get guest_path("web01")
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
