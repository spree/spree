require_relative '../../app/models/spree/order_updater.rb'
require 'active_support/core_ext/enumerable'

class FakeOrder
  attr_accessor :payment_total, :item_total, :adjustment_total, :total,
                :line_items, :payment_state, :changed_attributes

  def initialize
    @line_items = []
    @changed_attributes = {}
  end
end

describe OrderUpdater do
  let(:order) do
    FakeOrder.new
  end

  let(:updater) { OrderUpdater.new(order) }

  it "updates an order's totals" do
    order.stub :completed_payment_total => 1
    order.stub :line_item_total => 2
    order.stub :eligible_adjustments_total => 3
    updater.update_totals
    order.payment_total.should == 1
    order.total.should == 5
  end

  context "#update_payment_state" do
    context "if there are no line items" do
      before { order.stub :line_items => [] }

      context "if last payment did not fail" do
        before { order.stub :last_payment_failed? => false }
        it "is marked as balance_due" do
          updater.update_payment_state
          order.payment_state.should == 'balance_due'
        end
      end

      context "if last payment failed" do
        before { order.stub :last_payment_failed? => true }
        it "is marked as failed" do
          updater.update_payment_state
          order.payment_state.should == 'failed'
        end
      end
    end

    context "if there are line items" do
      before { order.stub :line_items => [stub] }
      context "if payment is over order total" do
        before do
          order.stub :last_payment_failed? => false
          order.stub :payment_total => 100
          order.stub :total => 99
        end

        it "is marked as credit_owed" do
          updater.update_payment_state
          order.payment_state.should == 'credit_owed'
        end
      end

      context "if order is paid" do
        before do
          order.stub :last_payment_failed? => false
          order.stub :payment_total => 100
          order.stub :total => 100
        end

        it "is marked as paid" do
          updater.update_payment_state
          order.payment_state.should == 'paid'
        end

      end
    end
  end

end
