require 'spec_helper'

describe Spree::Order, :type => :model do
  context "#all_adjustments" do
    # Regression test for #4537
    it "does not show adjustments from other, non-order adjustables" do
      order = Spree::Order.new(:id => 1)
      where_sql = order.all_adjustments.where_values.to_s
      expect(where_sql).to include("(adjustable_id = 1 AND adjustable_type = 'Spree::Order')")
    end
  end

  # Regression test for #2191
  context "when an order has an adjustment that zeroes the total, but another adjustment for shipping that raises it above zero" do
    let!(:persisted_order) { create(:order) }
    let!(:line_item) { create(:line_item) }
    let!(:shipping_method) do
      sm = create(:shipping_method)
      sm.calculator.preferred_amount = 10
      sm.save
      sm
    end

    before do
      # Don't care about available payment methods in this test
      allow(persisted_order).to receive_messages(:has_available_payment => false)
      persisted_order.line_items << line_item
      create(:adjustment, :amount => -line_item.amount, :label => "Promotion", :adjustable => line_item)
      persisted_order.state = 'delivery'
      persisted_order.save # To ensure new state_change event
    end

    it "transitions from delivery to payment" do
      allow(persisted_order).to receive_messages(payment_required?: true)
      persisted_order.next!
      expect(persisted_order.state).to eq("payment")
    end
  end
end
