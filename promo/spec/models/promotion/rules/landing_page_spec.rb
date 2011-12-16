require 'spec_helper'

describe Spree::Promotion::Rules::LandingPage do
  let(:rule) {
    rule = Spree::Promotion::Rules::LandingPage.new
    rule.preferred_path = '/content/deal'
    rule
  }
  let(:order) { mock_model(Spree::Order, :user => nil) }

  context "#eligible?(order)" do

    context "when visited paths option is given" do
      it "should be true if path is in visited paths" do
        rule.should be_eligible(order, :visited_paths => ['/content/deal'])
      end
      it "should be true if path is in visited paths but without leading slash" do
        rule.should be_eligible(order, :visited_paths => ['/content/deal'])
        rule.preferred_path = 'content/deal'
        rule.should be_eligible(order, :visited_paths => ['content/deal'])
      end
      it "should be false if path is not in visited paths" do
        rule.should_not be_eligible(order, :visited_paths => ['content/foo'])
      end
    end

    context "when visited paths option is not given" do
      it "should be true" do
        rule.should be_eligible(order)
      end
    end

  end
end

