require 'spec_helper'

describe Spree::PromotionRulesHelper do
  include Spree::PromotionRulesHelper

  it "does not include existing rules in options" do
    promotion = Spree::Promotion.new
    promotion.promotion_rules << Spree::Promotion::Rules::ItemTotal.new

    options = helper.options_for_promotion_rule_types(promotion)
    options.should_not =~ /ItemTotal/
  end
end
