module Spree
  module Promotions
    class DuplicatePromotionJob < Spree::BaseJob
      def perform(template_promotion_id:, batch_id:, options: {}, code: nil)
        promotion = Spree::Promotion.find(template_promotion_id)
        code = code || Spree::PromotionBatches::BatchCodeGenerator.build(batch_id, options)

        Spree::PromotionHandler::PromotionBatchDuplicator.new(promotion, batch_id, code: code).duplicate
      end
    end
  end
end
