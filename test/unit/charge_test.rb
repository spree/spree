require 'test_helper'

class ChargeTest < ActiveSupport::TestCase
  should_validate_presence_of :amount
  should_validate_presence_of :description
  context "order instance with charges" do
    setup do
      @charge = Factory(:tax_charge, :amount => 3.17)
      @order = Factory(:order, :charges => [@charge])
    end
    context "when adding another charge" do
      setup do 
        @order.charges << Factory(:ship_charge, :amount => 8.99)
        @order.save
      end
      
      should_change "@order.total.to_f", :by => 8.99
      should_change "@order.charge_total.to_f", :by => 8.99
      should_not_change "@order.item_total"
    end
    context "when destroying a charge" do
      setup do 
        @order.charges.clear
        @order.save
      end
      should_change "@order.total.to_f", :by => -3.17
      should_change "@order.charge_total.to_f", :by => -3.17
      should_not_change "@order.item_total"
    end
  end
  
end
