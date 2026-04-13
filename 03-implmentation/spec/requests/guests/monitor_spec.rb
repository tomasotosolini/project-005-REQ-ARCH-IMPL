require "rails_helper"

RSpec.describe "Guests::Monitor", type: :request do
  let!(:user) { create(:user) }

  let(:guest_record) do
    Xen::GuestRecord.new(
      name: "web01", id: 1, memory: 512, vcpus: 2, state: "-b----", time: 99.3
    )
  end

  # Keep the poll interval at zero so no real sleep occurs.
  before { stub_const("Guests::MonitorController::POLL_INTERVAL", 0) }

  # ActionController::Live streams body chunks to a pipe that rack-test cannot
  # reliably capture.  Content assertions live in the view spec for
  # guests/guests/_monitor_panel.  Here we only verify transport-level concerns.
  describe "GET /guests/:name/monitor" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get monitor_guest_path("web01")
        expect(response).to redirect_to(login_path)
      end
    end

    context "when authenticated" do
      before { post login_path, params: { email: user.email, password: "password123" } }

      before do
        call_count = 0
        allow(Xen::Monitor).to receive(:snapshot).with("web01") do
          call_count += 1
          raise IOError if call_count > 1

          guest_record
        end
      end

      it "responds with text/event-stream content type" do
        get monitor_guest_path("web01")
        expect(response.headers["Content-Type"]).to match(%r{text/event-stream})
      end

      it "responds with 200 OK" do
        get monitor_guest_path("web01")
        expect(response.status).to eq(200)
      end
    end
  end
end
