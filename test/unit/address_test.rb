require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  context Address do
    should_validate_presence_of :firstname, :lastname, :address1,
      :city, :zipcode, :country, :phone

    # this validation disabled for now 
    # should_not_allow_values_for :phone, "abcd", "1234"

    context "create from factory" do
      setup { Factory :address }
      should_change "Address.count", :by => 1
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
