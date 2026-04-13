require "rails_helper"

RSpec.describe "guests/guests/_monitor_panel", type: :view do
  let(:guest_record) do
    Xen::GuestRecord.new(
      name: "web01", id: 1, memory: 512, vcpus: 2, state: "-b----", time: 99.3
    )
  end

  context "with a running guest" do
    before { render partial: "guests/guests/monitor_panel", locals: { guest: guest_record, name: "web01" } }

    it "displays the guest memory" do
      expect(rendered).to include("512")
    end

    it "displays the guest vcpu count" do
      expect(rendered).to include("2")
    end

    it "displays the guest state" do
      expect(rendered).to include("-b----")
    end

    it "displays the domain ID" do
      expect(rendered).to include("1")
    end
  end

  context "with a stopped guest (nil)" do
    before { render partial: "guests/guests/monitor_panel", locals: { guest: nil, name: "web01" } }

    it "shows the not-running message" do
      expect(rendered).to include("not currently running")
    end

    it "does not render a table" do
      expect(rendered).not_to include("<table>")
    end
  end
end
