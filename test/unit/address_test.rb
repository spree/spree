require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  context Address do
    should_validate_presence_of :firstname, :lastname, :address1,
      :city, :zipcode, :country, :phone
    should_not_allow_values_for :phone, "abcd", "1234"

    context "create from factory" do
      setup { Factory :address }
      should_change "Address.count", :by => 1
    end

    context "instance" do
      setup do
        @address = Factory(:address)
      end

      should "not be allowed to be changed when have checkout" do
        @address.checkouts << Factory.build(:checkout, :bill_address => @address)
        assert @address.checkouts.length > 0
        assert !@address.update_attributes({:firstname=>"foo"})
      end

      should "not be allowed to be changed when have shippment" do
        @address.shipments << Factory.build(:shipment)
        assert !@address.update_attributes({:firstname=>"foo"})
      end
    end

    context "clone" do
      setup do
        @address = Factory(:address)
      end

      should("be valid") { assert @address.clone.valid? }
      ["user", "country", "state"].each do |field|
        should("have same #{field}") {
          assert_equal(@address.clone.send(field), @address.send(field))
        }
      end
    end
  end
end
