require 'spec_helper'

describe Spree::LegacyUser do
  # Regression test for #2844
  context "#last_incomplete_order" do
    let!(:user) { create(:user) }
    let!(:order_1) { create(:order, :created_at => 1.day.ago, :user => user) }
    let!(:order_2) { create(:order, :user => user) }

    it "returns correct order" do
      user.last_incomplete_spree_order.should == order_2
    end
  end
end
