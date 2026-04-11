require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    it "requires an email" do
      user.email = nil
      expect(user).not_to be_valid
    end

    it "requires a unique email (case-insensitive)" do
      create(:user, email: "test@example.com")
      user.email = "TEST@example.com"
      expect(user).not_to be_valid
    end

    it "requires a valid email format" do
      user.email = "not-an-email"
      expect(user).not_to be_valid
    end

    it "requires a role" do
      user.role = nil
      expect(user).not_to be_valid
    end

    it "rejects unknown roles" do
      user.role = "superuser"
      expect(user).not_to be_valid
    end

    it "accepts each defined role" do
      User::ROLES.each do |role|
        user.role = role
        expect(user).to be_valid, "expected #{role} to be a valid role"
      end
    end

    it "requires a password on create" do
      user.password = nil
      user.password_confirmation = nil
      expect(user).not_to be_valid
    end
  end

  describe "#admin?" do
    it "returns true for admin role" do
      user.role = "admin"
      expect(user.admin?).to be true
    end

    it "returns false for non-admin roles" do
      (User::ROLES - ["admin"]).each do |role|
        user.role = role
        expect(user.admin?).to be false
      end
    end
  end
end
