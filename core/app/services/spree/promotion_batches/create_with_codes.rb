module Spree
  module PromotionBatches
    class CreateWithCodes
      Error = Class.new(StandardError)

      def call(template_promotion:, codes:)
        validate_codes!(codes)

        promotion_batch = ::Spree::PromotionBatch.create!(
          template_promotion: template_promotion,
          codes: codes
        )

        ::Spree::PromotionBatches::PopulateJob.perform_later(promotion_batch.id)

        promotion_batch
      end

      private

      def validate_codes!(codes)
        raise Error, 'Codes cannot be empty' if codes.empty?
      end
    end
  end
end
