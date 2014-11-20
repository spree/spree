require 'spec_helper'

describe Spree::Promotion::Rules::ItemTotal, :type => :model do
  let(:rule) { Spree::Promotion::Rules::ItemTotal.new }
  let(:order) { double(:order) }

  before { rule.preferred_amount = 50 }

  context "preferred operator set to gt" do
    before { rule.preferred_operator = 'gt' }

    it "should be eligible when item total is greater than preferred amount" do
      allow(order).to receive_messages :item_total => 51
      expect(rule).to be_eligible(order)
    end

    it "should not be eligible when item total is equal to preferred amount" do
      allow(order).to receive_messages :item_total => 50
      expect(rule).not_to be_eligible(order)
    end

    it "should not be eligible when item total is lower than to preferred amount" do
      allow(order).to receive_messages :item_total => 49
      expect(rule).not_to be_eligible(order)
    end
  end

  context "preferred operator set to gte" do
    before { rule.preferred_operator = 'gte' }

    it "should be eligible when item total is greater than preferred amount" do
      allow(order).to receive_messages :item_total => 51
      expect(rule).to be_eligible(order)
    end

    it "should be eligible when item total is equal to preferred amount" do
      allow(order).to receive_messages :item_total => 50
      expect(rule).to be_eligible(order)
    end

    it "should not be eligible when item total is lower than to preferred amount" do
      allow(order).to receive_messages :item_total => 49
      expect(rule).not_to be_eligible(order)
    end
  end
end
