require 'csv'

module Spree
  module PromotionBatches
    class Export
      def call(promotion_batch:)
        promotions = promotion_batch.promotions

        ::CSV.generate do |csv|
          promotions.each { |promotion| csv << [promotion.code] }
        end
      end
    end
  end
end
