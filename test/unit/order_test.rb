require 'test_helper'

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

    context "#update_totals" do
      should "update totals" do
        order = Order.create!
        order.item_total = nil
        order.adjustment_total = nil
        order.total = nil
        order.update_totals
        assert_not_nil order.item_total
        assert_not_nil order.charge_total
        assert_not_nil order.total
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
    context "#complete" do
      should "change state from in_progress to new" do
        order = Order.create!
        assert_equal "in_progress", order.state
        order.complete!
        assert_equal "new", order.state
      end
      should "update checkout completed_at" do
        order = Order.create!
        assert order.completed_at.nil?
        order.complete!
        assert !order.completed_at.nil?
        assert !order.checkout.completed_at.nil?
      end
      should "create inventory units" do
        order = Order.create!
        order.line_items <<
                [Factory.build(:line_item, :quantity=>1, :order=>order),
                 Factory.build(:line_item, :quantity=>2, :order=>order)]
        assert_equal 0, order.inventory_units.count
        assert_equal 0, order.shipment.inventory_units.count
        order.complete!
        assert_equal 3, order.inventory_units.count
        assert_equal 3, order.shipment.inventory_units.count
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
