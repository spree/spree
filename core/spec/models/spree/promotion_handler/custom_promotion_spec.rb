require 'spec_helper'

class CustomPromotionRule < Spree::PromotionRule
  def applicable?(_promotable)
    false
  end
end

module Spree
  module PromotionHandler
    describe Cart, type: :model do
      let(:promotion) { Promotion.create(name: 'At line items') }
      let(:line_item) { create(:line_item) }
      let(:order) { line_item.order }
      let(:rule) { CustomPromotionRule.create(promotion: promotion) }

      it 'is not eligible' do
        promotion.promotion_rules << rule
        expect(promotion.eligible?(order)).to be false
      end
    end
  end
end
