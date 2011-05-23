require 'spec_helper'

describe Promotion::Rules::LandingPage do
  let(:rule) {
    rule = Promotion::Rules::LandingPage.new
    rule.preferred_path = '/deal'
    rule
  }
  let(:order) { mock_model(Order, :user => nil) }

  context "#eligible?(order)" do

    context "when visited paths option is given" do
      it "should be true if path is in visited paths" do
        rule.should be_eligible(order, :visited_paths => ['/deal'])
      end
      it "should be true if path is in visited paths but without leading slash" do
        rule.should be_eligible(order, :visited_paths => ['deal'])
        rule.preferred_path = 'deal'
        rule.should be_eligible(order, :visited_paths => ['/deal'])
      end
      it "should be false if path is not in visited paths" do
        rule.should_not be_eligible(order, :visited_paths => ['/foo'])
      end
    end

    context "when visited paths option is not given" do
      it "should be true" do
        rule.should be_eligible(order)
      end
    end

  end
end

