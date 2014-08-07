require 'spec_helper'

describe Spree::Promotion::Rules::UserLoggedIn do
  let(:rule) { Spree::Promotion::Rules::UserLoggedIn.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if order has an associated user" do
      user = double('User')
      order.stub(:user => user)

      rule.should be_eligible(order)
    end

    context "when user is not logged in" do
      before { order.stub(:user => nil) } # better to be explicit here
      it { expect(rule).not_to be_eligible(order) }
      it "sets an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "You need to login before applying this coupon code."
      end
    end
  end
end

