require 'spec_helper'

describe Spree::LegacyUser do
  # Regression test for #2844 + #3346
  context "#last_incomplete_order" do
    let!(:user) { create(:user) }
    let!(:order_1) { create(:order, :created_at => 1.day.ago, :user => user, :created_by => user) }
    let!(:order_2) { create(:order, :user => user, :created_by => user) }
    let!(:order_3) { create(:order, :user => user, :created_by => create(:user)) }

    it "returns correct order" do
      user.last_incomplete_spree_order.should == order_2
    end
  end
end
