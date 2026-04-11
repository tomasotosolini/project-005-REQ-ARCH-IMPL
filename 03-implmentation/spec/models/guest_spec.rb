require "rails_helper"

RSpec.describe Guest, type: :model do
  subject(:guest) { build(:guest) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(guest).to be_valid
    end

    it "requires a xen_name" do
      guest.xen_name = nil
      expect(guest).not_to be_valid
    end

    it "requires a unique xen_name" do
      create(:guest, xen_name: "my-vm")
      guest.xen_name = "my-vm"
      expect(guest).not_to be_valid
    end

    it "allows letters, numbers, hyphens and underscores" do
      guest.xen_name = "web-server_01"
      expect(guest).to be_valid
    end

    it "rejects spaces in xen_name" do
      guest.xen_name = "my vm"
      expect(guest).not_to be_valid
    end

    it "rejects special characters in xen_name" do
      guest.xen_name = "vm@host"
      expect(guest).not_to be_valid
    end
  end
end
