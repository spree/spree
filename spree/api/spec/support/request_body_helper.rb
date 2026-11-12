require 'spree/api/testing_support/openapi'

RequestBodyHelper = Spree::Api::TestingSupport::RequestBody

RSpec.configure do |config|
  config.extend RequestBodyHelper, type: :request
end
