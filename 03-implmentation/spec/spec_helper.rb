# frozen_string_literal: true
#
# Minimal spec_helper — no Rails dependency.
# These specs run against standalone Ruby scripts.
# When the Rails app is created this file will be superseded by rails_helper.rb,
# but specs under spec/bin/ will continue to require only spec_helper.

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
