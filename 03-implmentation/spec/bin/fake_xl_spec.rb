# frozen_string_literal: true
require 'spec_helper'
require 'open3'
require 'json'
require 'tmpdir'
require 'fileutils'

FAKE_XL_PATH = File.expand_path('../../bin/fake_xl', __dir__)

RSpec.describe 'bin/fake_xl' do
  # Each example gets its own isolated state directory.
  let(:work_dir)   { Dir.mktmpdir('fake-xen-spec') }
  let(:state_file) { File.join(work_dir, 'state.json') }
  let(:env)        { { 'FAKE_XEN_STATE' => state_file } }

  after { FileUtils.rm_rf(work_dir) }

  # ── helpers ──────────────────────────────────────────────────────────────────

  # Run bin/fake_xl with the isolated state env. Returns { stdout:, stderr:, exit_code: }.
  def run_xl(*args)
    stdout, stderr, status = Open3.capture3(env, 'ruby', FAKE_XL_PATH, *args.map(&:to_s))
    { stdout: stdout, stderr: stderr, exit_code: status.exitstatus }
  end

  def read_state
    JSON.parse(File.read(state_file))
  end

  def write_state(hash)
    File.write(state_file, JSON.generate(hash))
  end

  # Creates a minimal xl config file in work_dir and returns its path.
  def write_config(name:, vcpus: 2, memory: 1024)
    path = File.join(work_dir, "#{name}.cfg")
    File.write(path, <<~CFG)
      name   = "#{name}"
      vcpus  = #{vcpus}
      memory = #{memory}
    CFG
    path
  end

  # ── xl list ──────────────────────────────────────────────────────────────────

  describe 'xl list' do
    it 'exits 0' do
      expect(run_xl('list')[:exit_code]).to eq(0)
    end

    it 'always includes Domain-0' do
      result = run_xl('list')
      expect(result[:stdout]).to include('Domain-0')
    end

    it 'includes the standard header' do
      result = run_xl('list')
      expect(result[:stdout]).to match(/^Name\s+ID\s+Mem\s+VCPUs\s+State\s+Time/)
    end

    context 'with no state file' do
      it 'initialises cleanly and shows only Domain-0' do
        result = run_xl('list')
        lines = result[:stdout].lines.map(&:rstrip).reject(&:empty?)
        # header + dom0 only
        expect(lines.length).to eq(2)
        expect(lines.last).to match(/\ADomain-0\s/)
      end
    end

    context 'with running and stopped guests in state' do
      before do
        write_state(
          'guests' => [
            { 'name' => 'web-01', 'id' => 1, 'vcpus' => 2, 'memory' => 2048, 'state' => 'running' },
            { 'name' => 'db-01',  'id' => 2, 'vcpus' => 4, 'memory' => 4096, 'state' => 'stopped' }
          ],
          'next_id' => 3
        )
      end

      it 'shows running guests' do
        expect(run_xl('list')[:stdout]).to include('web-01')
      end

      it 'does not show stopped guests' do
        expect(run_xl('list')[:stdout]).not_to include('db-01')
      end
    end

    describe 'output format (column layout)' do
      before do
        write_state(
          'guests' => [
            { 'name' => 'testvm', 'id' => 5, 'vcpus' => 3, 'memory' => 3072, 'state' => 'running' }
          ],
          'next_id' => 6
        )
      end

      it 'produces a guest row with the correct column values' do
        line = run_xl('list')[:stdout].lines.find { |l| l.include?('testvm') }
        # Split on whitespace — tolerates spaces or tabs between columns
        cols = line.split
        # cols: name, id, mem, vcpus, state, time
        expect(cols[0]).to eq('testvm')
        expect(cols[1]).to eq('5')
        expect(cols[2]).to eq('3072')
        expect(cols[3]).to eq('3')
        expect(cols[4]).to match(/\A[r\-b]{6}\z/)
        expect(cols[5]).to match(/\A\d+\.\d\z/)
      end

      it 'produces a dom0 row with id 0' do
        line = run_xl('list')[:stdout].lines.find { |l| l.include?('Domain-0') }
        cols = line.split
        expect(cols[1]).to eq('0')
        expect(cols[4]).to eq('r-----')
      end
    end
  end

  # ── xl create ────────────────────────────────────────────────────────────────

  describe 'xl create' do
    context 'with a valid config file' do
      let(:config) { write_config(name: 'myvm', vcpus: 2, memory: 1024) }

      it 'exits 0' do
        expect(run_xl('create', config)[:exit_code]).to eq(0)
      end

      it 'adds the guest to the state as running' do
        run_xl('create', config)
        guest = read_state['guests'].find { |g| g['name'] == 'myvm' }
        expect(guest).not_to be_nil
        expect(guest['state']).to eq('running')
      end

      it 'records vcpus and memory from the config file' do
        run_xl('create', config)
        guest = read_state['guests'].find { |g| g['name'] == 'myvm' }
        expect(guest['vcpus']).to eq(2)
        expect(guest['memory']).to eq(1024)
      end

      it 'makes the guest appear in the subsequent xl list output' do
        run_xl('create', config)
        expect(run_xl('list')[:stdout]).to include('myvm')
      end

      it 'increments next_id' do
        run_xl('create', config)
        expect(read_state['next_id']).to eq(2)
      end
    end

    context 'with a missing config file' do
      it 'exits 1' do
        result = run_xl('create', '/nonexistent/path.cfg')
        expect(result[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        result = run_xl('create', '/nonexistent/path.cfg')
        expect(result[:stderr]).to match(/cannot open config file/i)
      end
    end

    context 'with a config file missing the name field' do
      let(:config) do
        path = File.join(work_dir, 'bad.cfg')
        File.write(path, "vcpus = 2\nmemory = 512\n")
        path
      end

      it 'exits 1' do
        expect(run_xl('create', config)[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        expect(run_xl('create', config)[:stderr]).to match(/could not determine guest name/i)
      end
    end

    context 'when the guest is already running' do
      let(:config) { write_config(name: 'myvm') }

      before { run_xl('create', config) }

      it 'exits 1' do
        expect(run_xl('create', config)[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        expect(run_xl('create', config)[:stderr]).to match(/already exists/i)
      end
    end

    context 'with a previously stopped guest' do
      let(:config) { write_config(name: 'myvm') }

      before do
        run_xl('create', config)
        run_xl('shutdown', 'myvm')
      end

      it 'exits 0' do
        expect(run_xl('create', config)[:exit_code]).to eq(0)
      end

      it 'makes the guest running again' do
        run_xl('create', config)
        expect(read_state['guests'].find { |g| g['name'] == 'myvm' }['state']).to eq('running')
      end

      it 'guest reappears in xl list' do
        run_xl('create', config)
        expect(run_xl('list')[:stdout]).to include('myvm')
      end
    end
  end

  # ── xl shutdown ───────────────────────────────────────────────────────────────

  describe 'xl shutdown' do
    let(:config) { write_config(name: 'target') }

    before { run_xl('create', config) }

    context 'with a running guest' do
      it 'exits 0' do
        expect(run_xl('shutdown', 'target')[:exit_code]).to eq(0)
      end

      it 'produces no stdout (matches real xl behaviour)' do
        expect(run_xl('shutdown', 'target')[:stdout]).to be_empty
      end

      it 'marks the guest as stopped in state' do
        run_xl('shutdown', 'target')
        expect(read_state['guests'].find { |g| g['name'] == 'target' }['state']).to eq('stopped')
      end

      it 'removes the guest from xl list output' do
        run_xl('shutdown', 'target')
        expect(run_xl('list')[:stdout]).not_to include('target')
      end
    end

    context 'with a non-existent guest' do
      it 'exits 1' do
        expect(run_xl('shutdown', 'no-such-vm')[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        expect(run_xl('shutdown', 'no-such-vm')[:stderr]).to match(/does not exist/i)
      end
    end

    context 'with an already-stopped guest' do
      before { run_xl('shutdown', 'target') }

      it 'exits 1' do
        expect(run_xl('shutdown', 'target')[:exit_code]).to eq(1)
      end
    end
  end

  # ── xl destroy ────────────────────────────────────────────────────────────────

  describe 'xl destroy' do
    let(:config) { write_config(name: 'target') }

    before { run_xl('create', config) }

    context 'with a running guest' do
      it 'exits 0' do
        expect(run_xl('destroy', 'target')[:exit_code]).to eq(0)
      end

      it 'produces no stdout' do
        expect(run_xl('destroy', 'target')[:stdout]).to be_empty
      end

      it 'marks the guest as stopped' do
        run_xl('destroy', 'target')
        expect(read_state['guests'].find { |g| g['name'] == 'target' }['state']).to eq('stopped')
      end

      it 'removes the guest from xl list' do
        run_xl('destroy', 'target')
        expect(run_xl('list')[:stdout]).not_to include('target')
      end
    end

    context 'with a non-existent guest' do
      it 'exits 1' do
        expect(run_xl('destroy', 'no-such-vm')[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        expect(run_xl('destroy', 'no-such-vm')[:stderr]).to match(/does not exist/i)
      end
    end
  end

  # ── xl vcpu-set ───────────────────────────────────────────────────────────────

  describe 'xl vcpu-set' do
    let(:config) { write_config(name: 'target', vcpus: 2) }

    before { run_xl('create', config) }

    context 'with a running guest' do
      it 'exits 0' do
        expect(run_xl('vcpu-set', 'target', 4)[:exit_code]).to eq(0)
      end

      it 'updates vcpus in state' do
        run_xl('vcpu-set', 'target', 4)
        expect(read_state['guests'].find { |g| g['name'] == 'target' }['vcpus']).to eq(4)
      end

      it 'reflects the new vcpu count in xl list output' do
        run_xl('vcpu-set', 'target', 4)
        line = run_xl('list')[:stdout].lines.find { |l| l.include?('target') }
        expect(line.split[3]).to eq('4')
      end
    end

    context 'with a stopped guest' do
      before { run_xl('shutdown', 'target') }

      it 'exits 1' do
        expect(run_xl('vcpu-set', 'target', 4)[:exit_code]).to eq(1)
      end

      it 'writes an error to stderr' do
        expect(run_xl('vcpu-set', 'target', 4)[:stderr]).to match(/does not exist/i)
      end
    end
  end

  # ── xl mem-set ────────────────────────────────────────────────────────────────

  describe 'xl mem-set' do
    let(:config) { write_config(name: 'target', memory: 1024) }

    before { run_xl('create', config) }

    context 'with a running guest' do
      it 'exits 0' do
        expect(run_xl('mem-set', 'target', 2048)[:exit_code]).to eq(0)
      end

      it 'updates memory in state' do
        run_xl('mem-set', 'target', 2048)
        expect(read_state['guests'].find { |g| g['name'] == 'target' }['memory']).to eq(2048)
      end

      it 'reflects the new memory value in xl list output' do
        run_xl('mem-set', 'target', 2048)
        line = run_xl('list')[:stdout].lines.find { |l| l.include?('target') }
        expect(line.split[2]).to eq('2048')
      end
    end

    context 'with a stopped guest' do
      before { run_xl('shutdown', 'target') }

      it 'exits 1' do
        expect(run_xl('mem-set', 'target', 2048)[:exit_code]).to eq(1)
      end
    end
  end

  # ── state persistence ─────────────────────────────────────────────────────────

  describe 'state persistence across invocations' do
    it 'retains guest metadata through a full shutdown/start lifecycle' do
      config = write_config(name: 'persistent', vcpus: 3, memory: 3072)
      run_xl('create', config)
      run_xl('shutdown', 'persistent')

      # After shutdown, metadata is preserved in state
      guest = read_state['guests'].find { |g| g['name'] == 'persistent' }
      expect(guest['vcpus']).to eq(3)
      expect(guest['memory']).to eq(3072)

      # Re-create from the same config and verify it runs again
      run_xl('create', config)
      expect(run_xl('list')[:stdout]).to include('persistent')
    end

    it 'accumulates multiple guests without collision' do
      run_xl('create', write_config(name: 'vm-a'))
      run_xl('create', write_config(name: 'vm-b'))
      run_xl('create', write_config(name: 'vm-c'))

      list = run_xl('list')[:stdout]
      expect(list).to include('vm-a')
      expect(list).to include('vm-b')
      expect(list).to include('vm-c')
      expect(read_state['next_id']).to eq(4)
    end
  end

  # ── error handling ────────────────────────────────────────────────────────────

  describe 'unknown subcommand' do
    it 'exits 1' do
      expect(run_xl('no-such-command')[:exit_code]).to eq(1)
    end

    it 'writes an error to stderr' do
      expect(run_xl('no-such-command')[:stderr]).to match(/unknown subcommand/i)
    end

    it 'produces no stdout' do
      expect(run_xl('no-such-command')[:stdout]).to be_empty
    end
  end

  describe 'missing subcommand' do
    it 'exits 1' do
      expect(run_xl[:exit_code]).to eq(1)
    end

    it 'writes an error to stderr' do
      expect(run_xl[:stderr]).not_to be_empty
    end
  end
end
