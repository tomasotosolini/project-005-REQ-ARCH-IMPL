require "rails_helper"

RSpec.describe "Guests::Lifecycle", type: :request do
  include ActiveJob::TestHelper

  let!(:user) { create(:user) }  # operator by default

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

    context "when logged in as viewer" do
      let!(:viewer) { create(:user, :viewer) }

      before do
        delete logout_path
        post login_path, params: { email: viewer.email, password: "password123" }
      end

      it "redirects to login with an authorization alert" do
        get new_guest_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  # ── POST /guests (create) ────────────────────────────────────────────────────

  describe "POST /guests" do
    context "with valid params" do
      it "enqueues a GuestOperationJob for 'create'" do
        expect {
          post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        }.to have_enqueued_job(GuestOperationJob).with("web02", "create", memory: 512, vcpus: 2)
      end

      it "creates a DB guest record with pending_operation 'creating'" do
        post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        guest = Guest.find_by!(xen_name: "web02")
        expect(guest.pending_operation).to eq("creating")
      end

      it "redirects to the guest show page with a notice" do
        post guests_path, params: { name: "web02", memory: "512", vcpus: "2" }
        expect(response).to redirect_to(guest_path("web02"))
        follow_redirect!
        expect(response.body).to include("is being created")
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

      it "does not enqueue a job" do
        expect {
          post guests_path, params: { name: "", memory: "512", vcpus: "2" }
        }.not_to have_enqueued_job(GuestOperationJob)
      end
    end
  end

  # ── POST /guests/:name/start ─────────────────────────────────────────────────

  describe "POST /guests/:name/start" do
    it "enqueues a GuestOperationJob for 'start'" do
      expect {
        post start_guest_path("web01")
      }.to have_enqueued_job(GuestOperationJob).with("web01", "start")
    end

    it "sets pending_operation to 'starting' on the guest record" do
      guest = create(:guest, xen_name: "web01")
      post start_guest_path("web01")
      expect(guest.reload.pending_operation).to eq("starting")
    end

    it "redirects to the guest show page with a notice" do
      post start_guest_path("web01")
      expect(response).to redirect_to(guest_path("web01"))
      follow_redirect!
      expect(response.body).to include("is starting")
    end
  end

  # ── POST /guests/:name/stop ──────────────────────────────────────────────────

  describe "POST /guests/:name/stop" do
    it "enqueues a GuestOperationJob for 'stop'" do
      expect {
        post stop_guest_path("web01")
      }.to have_enqueued_job(GuestOperationJob).with("web01", "stop")
    end

    it "sets pending_operation to 'stopping' on the guest record" do
      guest = create(:guest, xen_name: "web01")
      post stop_guest_path("web01")
      expect(guest.reload.pending_operation).to eq("stopping")
    end

    it "redirects to the guest show page with a notice" do
      post stop_guest_path("web01")
      expect(response).to redirect_to(guest_path("web01"))
      follow_redirect!
      expect(response.body).to include("is stopping")
    end
  end

  # ── DELETE /guests/:name ─────────────────────────────────────────────────────

  describe "DELETE /guests/:name" do
    it "enqueues a GuestOperationJob for 'destroy'" do
      expect {
        delete guest_path("web01")
      }.to have_enqueued_job(GuestOperationJob).with("web01", "destroy")
    end

    it "sets pending_operation to 'destroying' when a DB record exists" do
      guest = create(:guest, xen_name: "web01")
      delete guest_path("web01")
      expect(guest.reload.pending_operation).to eq("destroying")
    end

    it "redirects to the guests index with a notice" do
      delete guest_path("web01")
      expect(response).to redirect_to(guests_path)
      follow_redirect!
      expect(response.body).to include("is being deleted")
    end
  end
end
