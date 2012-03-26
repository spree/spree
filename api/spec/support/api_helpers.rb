module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def assert_unauthorized!
    json_response.should == { "error" => "You are not authorized to perform that action." }
    response.status.should == 401
  end

  def stub_authentication!
    controller.stub :check_for_api_key
    Spree::User.stub :find_by_api_key => current_user
  end

  # This method can be overriden (with a let block) inside a context
  # For instance, if you wanted to have an admin user instead.
  def current_user
    stub_model(Spree::User)
  end
end

module ApiTestSetup
  def sign_in_as_admin!
    let!(:current_user) do
      user = stub_model(Spree::User)
      user.should_receive(:has_role?).with("admin").and_return(true)
      user
    end
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, :type => :controller
  config.extend ApiTestSetup, :type => :controller
end

RSpec::Matchers.define :have_attributes do |expected_attributes|
  match do |actual|
    # actual is a Hash object representing an object, like this:
    # { "product" => { "name" => "Product #1" } }
    actual_attributes = actual.values.first.keys.map(&:to_sym)
    actual_attributes == expected_attributes.map(&:to_sym)
  end
end

