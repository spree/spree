module Spree
  module PromotionBatches
    class PopulateJob < Spree::BaseJob
      def perform(promotion_batch_id)
        promotion_batch = ::Spree::PromotionBatch.find(promotion_batch_id)
        Spree::PromotionBatches::Populate.new.call(promotion_batch: promotion_batch)
      end
    end
  end
end
