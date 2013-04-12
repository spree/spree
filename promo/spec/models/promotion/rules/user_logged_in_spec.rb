require 'spec_helper'

describe Spree::Promotion::Rules::UserLoggedIn do
  let(:rule) { Spree::Promotion::Rules::UserLoggedIn.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if user is logged in" do
      user = mock_model(Spree::LegacyUser, :anonymous? => false)
      order.stub(:user => user)

      rule.should be_eligible(order)
    end

    it "should not be eligible if user is not logged in" do
      rule.should_not be_eligible(order)
    end
  end
end

