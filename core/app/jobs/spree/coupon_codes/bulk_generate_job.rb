module Spree
  module CouponCodes
    class BulkGenerateJob < Spree::BaseJob
      def perform(promotion_id, quantity)
        promotion = Spree::Promotion.find(promotion_id)
        return unless promotion.present?

        Spree::CouponCodes::BulkGenerate.call(
          promotion: promotion,
          quantity: quantity
        )
      end
    end
  end
end
