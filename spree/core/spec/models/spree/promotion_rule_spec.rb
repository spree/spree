require 'spec_helper'

module Spree
  describe Spree::PromotionRule, type: :model do
    class BadTestRule < Spree::PromotionRule; end

    class TestRule < Spree::PromotionRule
      def eligible?
        true
      end
    end

    let!(:promotion) { create(:promotion) }

    it 'forces developer to implement eligible? method' do
      expect { BadTestRule.new.eligible? }.to raise_error(ArgumentError)
    end

    it 'validates unique rules for a promotion' do
      TestRule.create!(promotion: promotion)

      promotion_rule = TestRule.new(promotion: promotion)
      expect(promotion_rule).not_to be_valid
    end
  end
end
