module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end


  def stub_authentication!
    Spree::User.stub :find_by_api_key => current_user
  end

  # This method can be overriden (with a let block) inside a context
  # For instance, if you wanted to have an admin user instead.
  def current_user
    stub_model(Spree::User)
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

