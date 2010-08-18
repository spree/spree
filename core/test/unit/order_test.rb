require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# TODO: check logic of state machine (mayby separate test case?
# check seslling units / restocking

class OrderTest < ActiveSupport::TestCase
  context "Order" do
    should_have_many :line_items

    context "#create" do
      setup { @order = Order.create! }
      should_change("Checkout.count", :by => 1) { Checkout.count }
      should "generate token" do
        assert !@order.token.blank?
      end
      should "create default tax charge" do
        assert !@order.tax_charges.empty?
      end
    end

    context "#save" do
      should "remove line items if quantity drops to 0" do
        order = Order.create!
        order.line_items << [Factory(:line_item, :order=>order),Factory(:line_item, :order=>order)]
        assert order.line_items.length == 2
        order.line_items.first.quantity = 0
        order.save!
        assert order.line_items.length == 1
      end
      should "update item_total when line_item quantity changes" do
        order = Order.create!
        line_item = Factory(:line_item, :price=>111, :quantity=>1, :order=>order)
        order.line_items << line_item
        order.save!
        assert_equal 111,order.item_total

        line_item.quantity = 2
        order.save!
        assert_equal 222, order.item_total
      end
      should "create shipment with pending state" do
        order = Order.new
        assert order.shipments.empty?
        order.save!
        assert !order.shipments.empty?
        assert_equal 'pending', order.shipments.first.state
      end
      context "with empty stock" do
        should "be able to save order when allow_backorders is off" do
          order = Order.create!
          line_item = Factory(:line_item,:order => order)
          order.line_items << line_item
          order.complete
          #let's clear our stock..
          on_stock_count = line_item.variant.inventory_units.with_state("on_hand").count
          InventoryUnit.destroy_on_hand(line_item.variant, on_stock_count)
          #.. and turn backorders off
          Spree::Config.set(:allow_backorders => false)
          assert order.save!
          Spree::Config.set(:allow_backorders => true)
        end
      end
    end
    context "#pay!" do
      should "make all shipments ready" do
        order = Order.create!
        order.line_items << Factory(:line_item, :order=>order)
        order.complete!
        assert !order.shipments.empty?
        assert !order.shipments.all?(&:ready_to_ship?)
        order.pay!
        assert order.shipments.all?(&:ready_to_ship?)
      end
    end
    context "#ship!" do
      should "make all shipments shipped" do
        order = Order.create!
        order.line_items << Factory(:line_item, :order=>order)
        order.complete!
        order.pay!
        assert !order.shipments.empty?
        assert !order.shipments.all?(&:shipped?)
        order.ship!
        assert order.shipments.all?(&:shipped?)
      end
    end
    context "#under_paid!" do
      should "make all shipments pending" do
        order = Order.create!
        order.line_items << Factory(:line_item, :order=>order)
        order.complete!
        order.pay!
        assert !order.shipments.empty?
        assert !order.shipments.all?(&:pending?)
        order.under_paid!
        assert order.shipments.all?(&:pending?)
      end
    end
    context "" do
      setup do
        @order = Factory(:line_item, :quantity => 1, :price => 5.00).order
        @order.reload
        @order.save
        Factory(:payment, :payable => @order, :amount => 2.50)
        @order.reload
      end

      context "with partial payment" do
        should "have #outstanding_balance" do
          assert_equal 2.50, @order.outstanding_balance.to_f
        end
        should "have no #outstanding_credit" do
          assert_equal 0.00, @order.outstanding_credit.to_f
        end
      end

      context "with extra payment" do
        setup do
          @order.payments.first.update_attribute(:amount, 8.00)
        end
        should "have no #outstanding_balance" do
          assert_equal 0.00, @order.outstanding_balance.to_f
        end
        should "have #outstanding_credit" do
          assert_equal 3.00, @order.outstanding_credit.to_f
        end
      end

      context "with exact (full) payment" do
        setup do
          @order.payments.first.update_attribute(:amount, 5.00)
        end
        should "have no #outstanding_balance" do
          assert_equal 0.00, @order.outstanding_balance.to_f
        end
        should "have no #outstanding_credit" do
          assert_equal 0.00, @order.outstanding_credit.to_f
        end
      end
    end
  end
end
