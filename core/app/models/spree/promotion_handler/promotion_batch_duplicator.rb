module Spree
  module PromotionHandler
    class PromotionBatchDuplicator < Spree::PromotionDuplicatorCore
      def initialize(promotion, promotion_batch_id, code:)
        @promotion = promotion
        @promotion_batch_id = promotion_batch_id
        @code = code
      end

      def duplicate
        new_promotion = @promotion.dup
        new_promotion.usage_limit = 1
        new_promotion.promotion_batch_id = @promotion_batch_id
        new_promotion.path = "#{@promotion.path}_#{@code}"
        new_promotion.code = @code
        new_promotion.stores = @promotion.stores
        new_promotion.template = false

        ActiveRecord::Base.transaction do
          new_promotion.save
          copy_rules(new_promotion)
          copy_actions(new_promotion)
        end

        new_promotion
      end
    end
  end
end
