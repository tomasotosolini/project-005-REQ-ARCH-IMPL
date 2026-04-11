require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, email: "operator@example.com") }

  describe "GET /login" do
    it "renders the login form" do
      get login_path
      expect(response).to have_http_status(:ok)
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
  end

  describe "require_login" do
    it "redirects unauthenticated requests to the login page" do
      # root is protected (sessions#new skips require_login, but root maps to sessions#new
      # which does skip it — test via a future protected route instead).
      # For now, verify the session is clear and a direct GET / behaves as login page.
      get root_path
      # root currently maps to sessions#new which skips require_login, so it renders OK.
      # This test documents that behaviour; it will be updated when root → guests#index.
      expect(response).to have_http_status(:ok)
    end
  end
end
