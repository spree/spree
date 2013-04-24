require 'spec_helper'

module Spree
  describe Spree::PromotionRule do

    class BadTestRule < Spree::PromotionRule; end

    class TestRule < Spree::PromotionRule
      def eligible?
        true
      end
    end

    it "should force developer to implement eligible? method" do
      expect { BadTestRule.new.eligible? }.to raise_error
    end

    it "validates unique rules for a promotion" do
      p1 = TestRule.new
      p1.activator_id = 1
      p1.save

      p2 = TestRule.new
      p2.activator_id = 1
      p2.should_not be_valid
    end

  end
end
