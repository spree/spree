require 'spec_helper'

describe Spree::Promotion::Rules::UserLoggedIn, :type => :model do
  let(:rule) { Spree::Promotion::Rules::UserLoggedIn.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if order has an associated user" do
      user = double('User')
      allow(order).to receive_messages(:user => user)

      expect(rule).to be_eligible(order)
    end

    it "should not be eligible if user is not logged in" do
      allow(order).to receive_messages(:user => nil) # better to be explicit here
      expect(rule).not_to be_eligible(order)
    end
  end
end

