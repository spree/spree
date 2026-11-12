require 'spree/api/testing_support/filter_parameters'

RSpec.configure do |config|
  config.extend Spree::Api::TestingSupport::FilterParameters, type: :request
end
