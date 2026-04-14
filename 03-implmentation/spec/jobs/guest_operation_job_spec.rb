require "rails_helper"

RSpec.describe GuestOperationJob, type: :job do
  let!(:guest) { create(:guest, xen_name: "web01", pending_operation: "starting") }

  before do
    allow(Xen::Executor).to receive(:run)
  end

  # ── create ────────────────────────────────────────────────────────────────────

  describe "#perform with 'create'" do
    before do
      allow(Xen::Lifecycle).to receive(:create).and_return("/tmp/web01.cfg")
    end

    it "calls Xen::Lifecycle.create with nil disk and vif_bridge when not supplied" do
      described_class.perform_now("web01", "create", memory: 512, vcpus: 2)
      expect(Xen::Lifecycle).to have_received(:create).with(
        name: "web01", memory: 512, vcpus: 2, disk: nil, vif_bridge: nil
      )
    end

    it "passes disk and vif_bridge through to Xen::Lifecycle.create" do
      described_class.perform_now("web01", "create", memory: 512, vcpus: 2,
                                  disk: "phy:/dev/vg0/web01,xvda,rw", vif_bridge: "xenbr0")
      expect(Xen::Lifecycle).to have_received(:create).with(
        name: "web01", memory: 512, vcpus: 2,
        disk: "phy:/dev/vg0/web01,xvda,rw", vif_bridge: "xenbr0"
      )
    end

    it "clears pending_operation on success" do
      described_class.perform_now("web01", "create", memory: 512, vcpus: 2)
      expect(guest.reload.pending_operation).to be_nil
    end
  end

  # ── start ─────────────────────────────────────────────────────────────────────

  describe "#perform with 'start'" do
    before { allow(Xen::Lifecycle).to receive(:start) }

    it "calls Xen::Lifecycle.start" do
      described_class.perform_now("web01", "start")
      expect(Xen::Lifecycle).to have_received(:start).with("web01")
    end

    it "clears pending_operation on success" do
      described_class.perform_now("web01", "start")
      expect(guest.reload.pending_operation).to be_nil
    end
  end

  # ── stop ──────────────────────────────────────────────────────────────────────

  describe "#perform with 'stop'" do
    before { allow(Xen::Lifecycle).to receive(:stop) }

    it "calls Xen::Lifecycle.stop" do
      described_class.perform_now("web01", "stop")
      expect(Xen::Lifecycle).to have_received(:stop).with("web01")
    end

    it "clears pending_operation on success" do
      described_class.perform_now("web01", "stop")
      expect(guest.reload.pending_operation).to be_nil
    end
  end

  # ── destroy ───────────────────────────────────────────────────────────────────

  describe "#perform with 'destroy'" do
    before { allow(Xen::Lifecycle).to receive(:destroy) }

    it "calls Xen::Lifecycle.destroy" do
      described_class.perform_now("web01", "destroy")
      expect(Xen::Lifecycle).to have_received(:destroy).with("web01")
    end

    it "removes the DB guest record" do
      expect { described_class.perform_now("web01", "destroy") }.to change(Guest, :count).by(-1)
    end
  end

  # ── error handling ────────────────────────────────────────────────────────────

  describe "when Xen raises a CommandError" do
    before do
      allow(Xen::Lifecycle).to receive(:start).and_raise(
        Xen::CommandError.new("xl exited 1", stdout: "", stderr: "xl: domain does not exist")
      )
    end

    it "re-raises the error" do
      expect {
        described_class.perform_now("web01", "start")
      }.to raise_error(Xen::CommandError)
    end

    it "still clears pending_operation" do
      described_class.perform_now("web01", "start") rescue nil
      expect(guest.reload.pending_operation).to be_nil
    end
  end

  # ── unknown operation ─────────────────────────────────────────────────────────

  describe "with an unknown operation" do
    it "raises ArgumentError" do
      expect {
        described_class.perform_now("web01", "reboot")
      }.to raise_error(ArgumentError, /Unknown operation/)
    end
  end
end
