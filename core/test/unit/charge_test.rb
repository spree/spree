require 'test_helper'

class TestCharge < Charge; end

Charge.class_eval do
  private
  def self.subclasses
    self == Charge ? [TaxCharge, ShippingCharge, TestCharge] : []
  end
end

class ChargeTest < ActiveSupport::TestCase
  fixtures :payment_methods

  should_validate_presence_of :description

  context "Order" do
    setup do
      @order = Factory(:order)
    end

    should "create default tax charge" do
      assert_equal(1, @order.tax_charges.length)
      assert_equal(1, @order.charges.reload.length)
      assert_equal(0, @order.shipping_charges.length)
    end

    should "find all types of charges" do
      Charge.create(:order => @order, :description => "TestCharge")
      ShippingCharge.create(:order => @order, :description => "TestCharge")
      TaxCharge.create(:order => @order, :description => "TestCharge")
      TestCharge.create(:order => @order, :description => "TestCharge")
      assert_equal(5, @order.reload.charges.length) # 4 + 1 default tax charge
    end

    context "TaxCharge" do
      setup do
        @tax_charge = @order.tax_charges.first
        assert(@tax_charge, "Tax charge is not present")
      end

      should "set order as charge source" do
        assert_equal(@order, @tax_charge.adjustment_source)
      end

      should "not calculate tax_charge" do
        assert_equal(nil, @tax_charge.calculate_adjustment)
      end

      should "have amount = 0" do
        assert_equal(0, @tax_charge.amount.to_f)
      end
    end

    context "with checkout, shipping method and addresses" do
      setup do
        create_complete_order
        @order.update_attribute(:completed_at, nil)
        @ship_charge = @order.shipping_charges.first
        @tax_charge = @order.tax_charges.first
        assert(@ship_charge, "Shipping charge was not created")
        assert_equal @order, @ship_charge.order
        assert !@order.checkout_complete
      end

      should "have ship_address and at least one zone address belongs to" do
        assert(@order.shipment.address, "Ship_address is empty")
        assert_not_nil(Zone.global.include?(@order.shipment.address), "Default zone doesn't include address.")
        zones = Zone.match(@order.shipment.address)
        assert(!zones.empty?, "Zones are empty")
      end

      should "create default shipping charge" do
        assert_equal(1, @order.tax_charges.length)
        assert_equal(2, @order.charges.length)
        assert_equal(1, @order.shipping_charges.length)
      end

      should "calculate value for ship charge" do
        assert !@ship_charge.order.checkout_complete
        assert_nil(@ship_charge.read_attribute(:amount))
        assert_equal("10.0", @ship_charge.calculate_adjustment.to_s)
        assert_equal("10.0", @ship_charge.amount.to_s)
      end

      should "set first shipment as charge source of ship_charge" do
        assert_equal(@order.shipment, @ship_charge.adjustment_source)
      end

      should "calculate value of ship_charge" do
        assert_equal("10.0", @ship_charge.calculate_adjustment.to_s)
      end

      should "recalculate tax_charge, to be 0.05 of item total" do
        assert_not_nil(Zone.global.include?(@order.shipment.address), "Default zone doesn't include address.")
        assert_equal Zone.global, TaxRate.find(:first).zone
        assert(!Zone.global.tax_rates.empty?)
        tax = @order.line_items.reload.total * 0.05
        assert_equal(tax.to_s, @tax_charge.calculate_adjustment.to_s)
      end

      context "with line_items quantity changes" do
        setup do
          @order.line_items.first.update_attribute(:quantity, @order.line_items.first.quantity + 1)
          @order.save
          @tax_delta = @order.line_items.first.price * 0.05
          @total_delta = @order.line_items.first.price + @tax_delta
        end
        should_change("tax charge",  :by => @tax_delta)   { @order.tax_charges.first.amount }
        should_change("order total", :by => @total_delta) { @order.total }
      end
    end
  end
end
