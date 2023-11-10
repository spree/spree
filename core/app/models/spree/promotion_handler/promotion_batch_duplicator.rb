module Spree
  module PromotionHandler
    class PromotionBatchDuplicator < Spree::PromotionDuplicatorCore
      def initialize(promotion, promotion_batch_id, random_string: generate_random_string(4), code: nil)
        @promotion = promotion
        @promotion_batch_id = promotion_batch_id
        @random_string = random_string
        @code = code
      end

      def duplicate
        new_promotion = @promotion.dup
        new_promotion.usage_limit = 1
        new_promotion.promotion_batch_id = @promotion_batch_id
        new_promotion.path = "#{@promotion.path}_#{@random_string}"
        code_assignment(new_promotion)
        new_promotion.stores = @promotion.stores

        ActiveRecord::Base.transaction do
          new_promotion.save
          copy_rules(new_promotion)
          copy_actions(new_promotion)
        end

        new_promotion
      end

      private

      def code_assignment(new_promotion)
        if @code
          new_promotion.code = @code
        else
          new_promotion.generate_code=(true)
        end
      end
    end
  end
end
