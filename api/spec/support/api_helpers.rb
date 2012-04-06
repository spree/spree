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
    Spree::User.stub :find_by_api_key => current_api_user
  end

  # This method can be overriden (with a let block) inside a context
  # For instance, if you wanted to have an admin user instead.
  def current_api_user
    @current_api_user ||= stub_model(Spree::User, :email => "spree@example.com")
  end

  def image(filename)
    path = Pathname.new(__FILE__) + "../../../spec/fixtures" + filename
    File.open(path)
  end

  def upload_image(filename)
    fixture_file_upload(image(filename).path)
  end
end

module ApiTestSetup
  def sign_in_as_admin!
    let!(:current_api_user) do
      user = stub_model(Spree::User)
      user.should_receive(:has_role?).any_number_of_times.with("admin").and_return(true)
      user
    end
  end

  # Default kaminari's pagination to a certain range
  # Means that you don't need to create 25 objects to test pagination
  def default_per_page(count)
    before do
      @current_default_per_page = Kaminari.config.default_per_page
      Kaminari.config.default_per_page = 1
    end

    after do
      Kaminari.config.default_per_page = @current_default_per_page
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
    expected_attributes.map(&:to_sym).all? { |attr| actual_attributes.include?(attr) }
  end
end

