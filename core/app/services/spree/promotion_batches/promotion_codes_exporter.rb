module Spree
  module PromotionBatches
    class PromotionCodesExporter
      def initialize(params)
        @promotion_batch = find_promotion_batch(params[:id])
      end

      def call
        Spree::Core::Converters::CSV.to_csv(promo_codes)
      end

      private

      def find_promotion_batch(id)
        Spree::PromotionBatch.find(id)
      end

      def promo_codes
        @promotion_batch.promotions.map do |promotion|
          [promotion.code]
        end
      end
    end  
  end
end
