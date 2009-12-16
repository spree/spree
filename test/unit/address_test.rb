require 'test_helper'
Fixtures.create_fixtures("test/fixtures", %w(countries states))

class AddressTest < ActiveSupport::TestCase
  context Address do
    should_validate_presence_of :firstname, :lastname, :address1,
      :city, :zipcode, :country, :phone
    # this validation disabled for now
    # should_not_allow_values_for :phone, "abcd", "1234"

    context "create from factory" do
      setup { Factory :address }
      should_change("Address.count", :by => 1) { Address.count }
    end

    context "in USA" do
      setup do
        @address = Factory(:address)
        @address.country = Country.find_by_iso_name('US')
        @address.state = nil
      end
      should("be valid if state_name is US state") do
        @address.state_name = Faker::Address.us_state
        assert @address.valid?, "Address in USA should be valid for state #{@address.state_name}"
      end
      should("be valid if state_name is US state abbr") do
        @address.state_name = @address.country.states.rand.abbr
        assert @address.valid?, "Address in USA should be valid for state #{@address.state_name}"
      end
      should("be not valid if state_name is not US state") do
        @address.state_name = Faker::Address.uk_country
        assert !@address.valid?, "Address in USA should be not valid for state #{@address.state_name}"
      end
    end

    context "instance" do
      setup do
        @address = Factory(:address)
      end
        
      # these two properties now under control of checkout controller
      # should "not be allowed to be changed when have checkout" do
      # should "not be allowed to be changed when have shippment" do
    end

    context "clone" do
      setup do
        @address = Factory(:address)
      end

      should("be valid") { assert @address.clone.valid? }
      ["country", "state"].each do |field|
        should("have same #{field}") {
          assert_equal(@address.clone.send(field), @address.send(field))
        }
      end
    end
  end
end
