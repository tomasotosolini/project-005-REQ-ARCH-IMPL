require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, email: "operator@example.com") }

  # Root now renders guests#index which calls xl. Stub the executor so these
  # specs don't depend on xl being present in the test environment.
  before do
    allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(
      { stdout: "Name                                        ID   Mem VCPUs\tState\tTime(s)\n", stderr: "", success: true }
    )
  end

  describe "GET /login" do
    it "renders the login form when not logged in" do
      get login_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects to root when already logged in" do
      post login_path, params: { email: "operator@example.com", password: "password123" }
      get login_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "redirects to root and sets the session" do
        post login_path, params: { email: "operator@example.com", password: "password123" }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Logged in.")
      end

      it "is case-insensitive on email" do
        post login_path, params: { email: "OPERATOR@EXAMPLE.COM", password: "password123" }
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid password" do
      it "re-renders the login form with an alert" do
        post login_path, params: { email: "operator@example.com", password: "wrong" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email or password.")
      end
    end

    context "with unknown email" do
      it "re-renders the login form with an alert" do
        post login_path, params: { email: "nobody@example.com", password: "password123" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email or password.")
      end
    end
  end

  describe "DELETE /logout" do
    before do
      post login_path, params: { email: "operator@example.com", password: "password123" }
    end

    it "clears the session and redirects to login" do
      delete logout_path
      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("Logged out.")
    end

    it "re-login is possible after logout" do
      delete logout_path
      post login_path, params: { email: "operator@example.com", password: "password123" }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "require_login" do
    it "redirects unauthenticated requests to the login page" do
      get root_path
      expect(response).to redirect_to(login_path)
    end

    it "allows access to root after login" do
      post login_path, params: { email: "operator@example.com", password: "password123" }
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
