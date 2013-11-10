require 'spec_helper'

describe Spree::Promotion::Rules::User do
  let(:rule) { Spree::Promotion::Rules::User.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should not be eligible if users are not provided" do
      rule.should_not be_eligible(order)
    end

    it "should be eligible if users include user placing the order" do
      user = mock_model(Spree::LegacyUser)
      users = [user, mock_model(Spree::LegacyUser)]
      rule.stub(:users => users)
      order.stub(:user => user)

      rule.should be_eligible(order)
    end

    it "should not be eligible if user placing the order is not listed" do
      order.stub(:user => mock_model(Spree::LegacyUser))
      users = [mock_model(Spree::LegacyUser), mock_model(Spree::LegacyUser)]
      rule.stub(:users => users)

      rule.should_not be_eligible(order)
    end

    # Regression test for #3885
    it "can assign to user_ids" do
      user1 = Spree::LegacyUser.create!(:email => "test1@example.com")
      user2 = Spree::LegacyUser.create!(:email => "test2@example.com")
      lambda { rule.user_ids = "#{user1.id}, #{user2.id}" }.should_not raise_error
    end
  end
end
