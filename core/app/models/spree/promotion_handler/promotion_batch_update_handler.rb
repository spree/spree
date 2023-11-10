module Spree
  module PromotionHandler
    class PromotionBatchUpdateHandler < Spree::PromotionDuplicatorCore
      def initialize(promotion, promotion_batch_id, descendant_promotion)
        @promotion = promotion
        @promotion_batch_id = promotion_batch_id
        @descendant_promotion = descendant_promotion
      end

      def duplicate
        new_promotion = @promotion.dup
        new_promotion.usage_limit = 1
        new_promotion.promotion_batch_id = @promotion_batch_id
        new_promotion.path = @descendant_promotion.path
        new_promotion.code = @descendant_promotion.code
        new_promotion.stores = @promotion.stores

        ActiveRecord::Base.transaction do
          @descendant_promotion.destroy!
          new_promotion.save
          copy_rules(new_promotion)
          copy_actions(new_promotion)
        end

        new_promotion
      end
    end
  end
end
