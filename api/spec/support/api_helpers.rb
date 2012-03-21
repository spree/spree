module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def api_get(action, params={})
    get action, params.merge!(:use_route => :spree, :format => :json)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, :type => :controller
end

RSpec::Matchers.define :have_attributes do |expected_attributes|
  match do |actual|
    # actual is a Hash object representing an object, like this:
    # { "product" => { "name" => "Product #1" } }
    actual_attributes = actual.values.first.keys.map(&:to_sym)
    actual_attributes == expected_attributes.map(&:to_sym)
  end
end

