# frozen_string_literal: true
require 'json'
require 'fileutils'

namespace :fake_xen do
  STATE_FILE = Rails.root.join('tmp', 'fake-xen', 'state.json')

  desc 'Reset fake Xen state to empty (no guests running)'
  task :reset do
    FileUtils.mkdir_p(STATE_FILE.dirname)
    File.write(STATE_FILE, JSON.pretty_generate('guests' => [], 'next_id' => 1))
    puts 'Fake Xen state reset: no guests.'
  end

  desc 'Seed fake Xen with sample guests (2 running, 1 stopped)'
  task seed: :reset do
    state = {
      'guests' => [
        { 'name' => 'web-01',   'id' => 1, 'vcpus' => 2, 'memory' => 2048, 'state' => 'running' },
        { 'name' => 'db-01',    'id' => 2, 'vcpus' => 4, 'memory' => 4096, 'state' => 'running' },
        { 'name' => 'cache-01', 'id' => 3, 'vcpus' => 1, 'memory' => 1024, 'state' => 'stopped' }
      ],
      'next_id' => 4
    }
    File.write(STATE_FILE, JSON.pretty_generate(state))
    puts 'Fake Xen seeded: web-01 (running), db-01 (running), cache-01 (stopped).'
  end

  desc 'Show current fake Xen state'
  task :status do
    unless STATE_FILE.exist?
      puts 'No state file. Run: rake fake_xen:reset'
      next
    end
    state = JSON.parse(STATE_FILE.read)
    puts "State file : #{STATE_FILE}"
    puts "Next ID    : #{state['next_id']}"
    puts "\nGuests:"
    if state['guests'].empty?
      puts '  (none)'
    else
      state['guests'].each do |g|
        puts format('  %-20s  state=%-8s  vcpus=%d  memory=%d MiB  id=%d',
                    g['name'], g['state'], g['vcpus'], g['memory'], g['id'])
      end
    end
  end
end
