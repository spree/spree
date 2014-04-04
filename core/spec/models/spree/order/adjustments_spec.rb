require 'spec_helper'

describe Spree::Order do
  context "#all_adjustments" do
    # Regression test for #4537
    it "does not show adjustments from other, non-order adjustables" do
      order = Spree::Order.new(:id => 1)
      where_sql = order.all_adjustments.where_values.to_s
      where_sql.should include("(adjustable_id = 1 AND adjustable_type = 'Spree::Order')")
    end
  end
end
