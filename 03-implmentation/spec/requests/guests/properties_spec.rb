require "rails_helper"

RSpec.describe "Guests::Properties", type: :request do
  let!(:user) { create(:user) }  # operator by default

  let(:xl_list_running) do
    <<~XL
      Name                                        ID   Mem VCPUs\tState\tTime(s)
      Domain-0                                       0  1024     1\tr-----\t55555.0
      web01                                          1   512     2\t-b----\t   99.3
    XL
  end

  let(:xl_list_empty) do
    <<~XL
      Name                                        ID   Mem VCPUs\tState\tTime(s)
      Domain-0                                       0  1024     1\tr-----\t55555.0
    XL
  end

  before do
    post login_path, params: { email: user.email, password: "password123" }
  end

  # ── GET /guests/:name/properties/edit (running guest) ─────────────────────────

  describe "GET /guests/:name/properties/edit — running guest" do
    before do
      allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
        { stdout: xl_list_running, stderr: "", success: true }
      )
    end

    it "renders the edit form with current Xen values" do
      get edit_guest_properties_path("web01")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("512")  # memory
      expect(response.body).to include("2")    # vcpus
    end

    it "notes that the guest is running" do
      get edit_guest_properties_path("web01")
      expect(response.body).to include("running")
    end

    context "when unauthenticated" do
      it "redirects to login" do
        delete logout_path
        get edit_guest_properties_path("web01")
        expect(response).to redirect_to(login_path)
      end
    end

    context "when logged in as viewer" do
      let!(:viewer) { create(:user, :viewer) }

      before do
        delete logout_path
        post login_path, params: { email: viewer.email, password: "password123" }
      end

      it "redirects to login with an authorization alert" do
        get edit_guest_properties_path("web01")
        expect(response).to redirect_to(login_path)
      end
    end
  end

  # ── GET /guests/:name/properties/edit (stopped guest) ─────────────────────────

  describe "GET /guests/:name/properties/edit — stopped guest" do
    let!(:db_guest) { create(:guest, xen_name: "web01") }

    before do
      allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
        { stdout: xl_list_empty, stderr: "", success: true }
      )
      allow(Xen::Properties).to receive(:read_config).with("web01").and_return(
        { vcpus: 2, memory: 512 }
      )
    end

    it "renders the edit form with config file values" do
      get edit_guest_properties_path("web01")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("512")
      expect(response.body).to include("2")
    end

    it "notes that the guest is stopped" do
      get edit_guest_properties_path("web01")
      expect(response.body).to include("stopped")
    end
  end

  # ── PATCH /guests/:name/properties (running guest) ────────────────────────────

  describe "PATCH /guests/:name/properties — running guest" do
    before do
      allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
        { stdout: xl_list_running, stderr: "", success: true }
      )
      allow(Xen::Properties).to receive(:vcpu_set)
      allow(Xen::Properties).to receive(:mem_set)
      allow(Xen::Properties).to receive(:update_config)
    end

    context "with valid params" do
      it "calls vcpu_set with the new value" do
        patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
        expect(Xen::Properties).to have_received(:vcpu_set).with("web01", 4)
      end

      it "calls mem_set with the new value" do
        patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
        expect(Xen::Properties).to have_received(:mem_set).with("web01", 1024)
      end

      it "calls update_config to persist changes" do
        patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
        expect(Xen::Properties).to have_received(:update_config).with(
          "web01", vcpus: 4, memory: 1024
        )
      end

      it "redirects to the guest show page with a notice" do
        patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
        expect(response).to redirect_to(guest_path("web01"))
        follow_redirect!
        expect(response.body).to include("Properties updated")
      end
    end

    context "with vcpus < 1" do
      it "renders the form again with unprocessable_entity status" do
        patch guest_properties_path("web01"), params: { vcpus: "0", memory: "512" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("at least 1")
      end

      it "does not call Xen::Properties" do
        patch guest_properties_path("web01"), params: { vcpus: "0", memory: "512" }
        expect(Xen::Properties).not_to have_received(:vcpu_set)
        expect(Xen::Properties).not_to have_received(:update_config)
      end
    end

    context "with memory < 16" do
      it "renders the form again with unprocessable_entity status" do
        patch guest_properties_path("web01"), params: { vcpus: "2", memory: "8" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("at least 16")
      end
    end

    context "when Xen raises a CommandError" do
      before do
        allow(Xen::Properties).to receive(:vcpu_set).and_raise(
          Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: invalid vcpu count")
        )
      end

      it "renders the form again with unprocessable_entity status" do
        patch guest_properties_path("web01"), params: { vcpus: "99", memory: "512" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Could not update properties")
      end
    end
  end

  # ── PATCH /guests/:name/properties (stopped guest) ────────────────────────────

  describe "PATCH /guests/:name/properties — stopped guest" do
    let!(:db_guest) { create(:guest, xen_name: "web01") }

    before do
      allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
        { stdout: xl_list_empty, stderr: "", success: true }
      )
      allow(Xen::Properties).to receive(:read_config).with("web01").and_return(
        { vcpus: 2, memory: 512 }
      )
      allow(Xen::Properties).to receive(:vcpu_set)
      allow(Xen::Properties).to receive(:mem_set)
      allow(Xen::Properties).to receive(:update_config)
    end

    it "does not call vcpu_set or mem_set" do
      patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
      expect(Xen::Properties).not_to have_received(:vcpu_set)
      expect(Xen::Properties).not_to have_received(:mem_set)
    end

    it "calls update_config to persist changes to the config file" do
      patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
      expect(Xen::Properties).to have_received(:update_config).with(
        "web01", vcpus: 4, memory: 1024
      )
    end

    it "redirects to the guest show page with a notice" do
      patch guest_properties_path("web01"), params: { vcpus: "4", memory: "1024" }
      expect(response).to redirect_to(guest_path("web01"))
      follow_redirect!
      expect(response.body).to include("Properties updated")
    end
  end
end
