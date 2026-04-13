require "rails_helper"

RSpec.describe "Guests::Lifecycle", type: :request do
  let!(:user) { create(:user) }

  let(:xl_list_output) do
    <<~XL
      Name                                        ID   Mem VCPUs\tState\tTime(s)
      Domain-0                                       0  1024     1\tr-----\t55555.0
      web01                                          1   512     2\t-b----\t   99.3
    XL
  end

  before do
    allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
      { stdout: xl_list_output, stderr: "", success: true }
    )
    post login_path, params: { email: user.email, password: "password123" }
  end

  # ── GET /guests/new ──────────────────────────────────────────────────────────

  describe "GET /guests/new" do
    it "renders the new guest form" do
      get new_guest_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New Guest")
    end

    context "when unauthenticated" do
      it "redirects to login" do
        delete logout_path
        get new_guest_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  # ── POST /guests (create) ────────────────────────────────────────────────────

  describe "POST /guests" do
    before do
      allow(Xen::Lifecycle).to receive(:create).and_return("/tmp/web02.cfg")
    end

    context "with valid params" do
      it "calls Xen::Lifecycle.create with the given params" do
        post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        expect(Xen::Lifecycle).to have_received(:create).with(
          name: "web02", memory: 512, vcpus: 2
        )
      end

      it "creates a DB guest record" do
        expect {
          post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        }.to change(Guest, :count).by(1)
        expect(Guest.find_by(xen_name: "web02")).not_to be_nil
      end

      it "redirects to the guest show page with a notice" do
        post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        expect(response).to redirect_to(guest_path("web02"))
        follow_redirect!
        expect(response.body).to include("created and started")
      end

      it "does not duplicate a DB record when the guest already exists" do
        create(:guest, xen_name: "web02")
        expect {
          post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        }.not_to change(Guest, :count)
      end
    end

    context "with a blank name" do
      it "renders the form again with unprocessable_entity status" do
        post guests_path, params: { name: "", memory: "512", vcpus: "2" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Name is required")
      end

      it "does not call Xen::Lifecycle.create" do
        post guests_path, params: { name: "", memory: "512", vcpus: "2" }
        expect(Xen::Lifecycle).not_to have_received(:create)
      end
    end

    context "when Xen raises a CommandError" do
      before do
        allow(Xen::Lifecycle).to receive(:create).and_raise(
          Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: domain 'web02' already exists")
        )
      end

      it "renders the form again with unprocessable_entity status" do
        post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("already exists")
      end
    end
  end

  # ── POST /guests/:name/start ─────────────────────────────────────────────────

  describe "POST /guests/:name/start" do
    before { allow(Xen::Lifecycle).to receive(:start) }

    it "calls Xen::Lifecycle.start with the guest name" do
      post start_guest_path("web01")
      expect(Xen::Lifecycle).to have_received(:start).with("web01")
    end

    it "redirects to the guest show page with a notice" do
      post start_guest_path("web01")
      expect(response).to redirect_to(guest_path("web01"))
      follow_redirect!
      expect(response.body).to include("started")
    end

    context "when Xen raises a CommandError" do
      before do
        allow(Xen::Lifecycle).to receive(:start).and_raise(
          Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: domain 'web01' already exists")
        )
      end

      it "redirects to the show page with an alert" do
        post start_guest_path("web01")
        expect(response).to redirect_to(guest_path("web01"))
        follow_redirect!
        expect(response.body).to include("Could not start")
      end
    end
  end

  # ── POST /guests/:name/stop ──────────────────────────────────────────────────

  describe "POST /guests/:name/stop" do
    before { allow(Xen::Lifecycle).to receive(:stop) }

    it "calls Xen::Lifecycle.stop with the guest name" do
      post stop_guest_path("web01")
      expect(Xen::Lifecycle).to have_received(:stop).with("web01")
    end

    it "redirects to the guest show page with a notice" do
      post stop_guest_path("web01")
      expect(response).to redirect_to(guest_path("web01"))
      follow_redirect!
      expect(response.body).to include("stopped")
    end

    context "when Xen raises a CommandError" do
      before do
        allow(Xen::Lifecycle).to receive(:stop).and_raise(
          Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: domain 'web01' does not exist")
        )
      end

      it "redirects to the show page with an alert" do
        post stop_guest_path("web01")
        expect(response).to redirect_to(guest_path("web01"))
        follow_redirect!
        expect(response.body).to include("Could not stop")
      end
    end
  end

  # ── DELETE /guests/:name ─────────────────────────────────────────────────────

  describe "DELETE /guests/:name" do
    before { allow(Xen::Lifecycle).to receive(:destroy) }

    context "when a DB record exists" do
      let!(:db_guest) { create(:guest, xen_name: "web01") }

      it "calls Xen::Lifecycle.destroy with the guest name" do
        delete guest_path("web01")
        expect(Xen::Lifecycle).to have_received(:destroy).with("web01")
      end

      it "removes the DB guest record" do
        expect { delete guest_path("web01") }.to change(Guest, :count).by(-1)
      end

      it "redirects to the guests index with a notice" do
        delete guest_path("web01")
        expect(response).to redirect_to(guests_path)
        follow_redirect!
        expect(response.body).to include("deleted")
      end
    end

    context "when no DB record exists" do
      it "still calls Xen::Lifecycle.destroy" do
        delete guest_path("web01")
        expect(Xen::Lifecycle).to have_received(:destroy).with("web01")
      end

      it "redirects to the guests index" do
        delete guest_path("web01")
        expect(response).to redirect_to(guests_path)
      end
    end

    context "when Xen raises a CommandError" do
      before do
        allow(Xen::Lifecycle).to receive(:destroy).and_raise(
          Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: permission denied")
        )
      end

      it "redirects to the show page with an alert" do
        delete guest_path("web01")
        expect(response).to redirect_to(guest_path("web01"))
        follow_redirect!
        expect(response.body).to include("Could not delete")
      end
    end
  end
end
