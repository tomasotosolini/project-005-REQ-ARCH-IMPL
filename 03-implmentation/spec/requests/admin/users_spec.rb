require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:other_user) { create(:user, role: "user") }

  before do
    post login_path, params: { email: admin.email, password: "password123" }
  end

  # ── Authorization ─────────────────────────────────────────────────────────────

  describe "non-admin access" do
    let!(:regular_user) { create(:user, role: "user") }

    before do
      delete logout_path
      post login_path, params: { email: regular_user.email, password: "password123" }
    end

    it "redirects GET /admin/users to root" do
      get admin_users_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "unauthenticated access" do
    before { delete logout_path }

    it "redirects GET /admin/users to login" do
      get admin_users_path
      expect(response).to redirect_to(login_path)
    end
  end

  # ── GET /admin/users ──────────────────────────────────────────────────────────

  describe "GET /admin/users" do
    it "returns 200 and lists users" do
      get admin_users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
      expect(response.body).to include(other_user.email)
    end
  end

  # ── GET /admin/users/new ──────────────────────────────────────────────────────

  describe "GET /admin/users/new" do
    it "renders the new user form" do
      get new_admin_user_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New User")
    end
  end

  # ── POST /admin/users ─────────────────────────────────────────────────────────

  describe "POST /admin/users" do
    context "with valid params" do
      let(:valid_params) do
        { user: { email: "new@example.com", password: "secret123",
                  password_confirmation: "secret123", role: "guest" } }
      end

      it "creates a new user" do
        expect { post admin_users_path, params: valid_params }.to change(User, :count).by(1)
      end

      it "redirects to users index with notice" do
        post admin_users_path, params: valid_params
        expect(response).to redirect_to(admin_users_path)
        follow_redirect!
        expect(response.body).to include("User created")
      end
    end

    context "with invalid params (blank email)" do
      let(:invalid_params) do
        { user: { email: "", password: "secret123",
                  password_confirmation: "secret123", role: "guest" } }
      end

      it "does not create a user" do
        expect { post admin_users_path, params: invalid_params }.not_to change(User, :count)
      end

      it "re-renders the form with unprocessable_entity" do
        post admin_users_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with mismatched password confirmation" do
      let(:mismatch_params) do
        { user: { email: "new@example.com", password: "secret123",
                  password_confirmation: "wrong", role: "guest" } }
      end

      it "re-renders the form" do
        post admin_users_path, params: mismatch_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── GET /admin/users/:id/edit ─────────────────────────────────────────────────

  describe "GET /admin/users/:id/edit" do
    it "renders the edit form" do
      get edit_admin_user_path(other_user)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit User")
    end
  end

  # ── PATCH /admin/users/:id ────────────────────────────────────────────────────

  describe "PATCH /admin/users/:id" do
    context "changing the role" do
      it "updates the user's role" do
        patch admin_user_path(other_user),
              params: { user: { role: "guest", password: "", password_confirmation: "" } }
        expect(other_user.reload.role).to eq("guest")
      end

      it "redirects to users index with notice" do
        patch admin_user_path(other_user),
              params: { user: { role: "guest", password: "", password_confirmation: "" } }
        expect(response).to redirect_to(admin_users_path)
        follow_redirect!
        expect(response.body).to include("User updated")
      end
    end

    context "changing the password (non-blank)" do
      it "accepts the new password" do
        patch admin_user_path(other_user),
              params: { user: { password: "newpassword", password_confirmation: "newpassword",
                                role: "user" } }
        expect(response).to redirect_to(admin_users_path)
      end
    end

    context "leaving password blank" do
      it "does not change the password digest" do
        old_digest = other_user.password_digest
        patch admin_user_path(other_user),
              params: { user: { email: other_user.email, password: "",
                                password_confirmation: "", role: "user" } }
        expect(other_user.reload.password_digest).to eq(old_digest)
      end
    end

    context "with invalid data" do
      it "re-renders the form with unprocessable_entity" do
        patch admin_user_path(other_user),
              params: { user: { email: "", role: "user" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── DELETE /admin/users/:id ───────────────────────────────────────────────────

  describe "DELETE /admin/users/:id" do
    it "deletes the user" do
      expect { delete admin_user_path(other_user) }.to change(User, :count).by(-1)
    end

    it "redirects to users index with notice" do
      delete admin_user_path(other_user)
      expect(response).to redirect_to(admin_users_path)
      follow_redirect!
      expect(response.body).to include("User deleted")
    end

    context "when the admin tries to delete themselves" do
      it "does not delete the user" do
        expect { delete admin_user_path(admin) }.not_to change(User, :count)
      end

      it "redirects with an alert" do
        delete admin_user_path(admin)
        expect(response).to redirect_to(admin_users_path)
        follow_redirect!
        expect(response.body).to include("cannot delete your own account")
      end
    end
  end
end
