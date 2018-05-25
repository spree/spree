# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../dummy/config/environment', __FILE__)
require 'rspec/rails'
require 'ffaker'
require 'spree_sample'

RSpec.configure do |config|
  config.color = true
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Config for running specs while have transition period from Paperclip to ActiveStorage
  if Rails.application.config.use_paperclip
    config.filter_run_excluding :active_storage
  else
    config.filter_run_including :active_storage
    config.run_all_when_everything_filtered = true
  end

  config.include FactoryBot::Syntax::Methods

  config.order = :random
  Kernel.srand config.seed
end
