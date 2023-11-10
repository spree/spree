module Spree
  module Promotions
    class HandleDescendantPromotionJob < Spree::BaseJob
      def perform(template_promotion_id:, descendant_promotion_id:, promotion_batch_id:)
        template_promotion = find_promotion(template_promotion_id)
        descendant_promotion = find_promotion(descendant_promotion_id)

        handle_promotion(template_promotion, promotion_batch_id, descendant_promotion)
      end

      private

      def find_promotion(id)
        Spree::Promotion.find(id)
      end

      def handle_promotion(template_promotion, promotion_batch_id, descendant_promotion)
        Spree::PromotionHandler::PromotionBatchUpdateHandler.new(template_promotion, promotion_batch_id, descendant_promotion).duplicate
      end
    end
  end
end
