require 'spec_helper'

module Spree
  describe Spree::PromotionRule, :type => :model do

    class BadTestRule < Spree::PromotionRule; end

    it "should force developer to implement eligible? method" do
      expect { BadTestRule.new.eligible? }.to raise_error(ArgumentError)
    end
  end
end
