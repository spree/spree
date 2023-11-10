module Spree
  module PromotionBatches
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(promotion_batch:)
        ActiveRecord::Base.transaction do
          promotion_batch.promotions.destroy_all
          promotion_batch.update(template_promotion_id: nil)
          promotion_batch.destroy!
        end
      end
    end
  end
end
