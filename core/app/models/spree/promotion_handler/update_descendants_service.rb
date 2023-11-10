module Spree
  module PromotionHandler
    class UpdateDescendantsService
      def initialize(template_promotion)
        @template_promotion = template_promotion
      end

      def call
        return unless promotion_batches?

        unused_promotions_ids_by_batch.each do |batch|
          batch.each do |batch_id, promotion_ids|
            promotion_ids.each do |promotion_id|
              Spree::Promotions::HandleDescendantPromotionJob.perform_later(
                template_promotion_id: @template_promotion.id,
                descendant_promotion_id: promotion_id,
                promotion_batch_id: batch_id
              )
            end
          end
        end
      end

      private

      def promotion_batches?
        promotion_batches.any?
      end

      def promotion_batches
        @promotion_batches = Spree::PromotionBatch.where(template_promotion_id: @template_promotion.id)
      end

      def unused_promotions_ids_by_batch
        @promotion_batches.map do |batch|
          {batch.id => unused_promotions_ids(batch)}
        end
      end

      def unused_promotions_ids(batch)
        batch.promotions
          .includes(:promotion_actions)
          .select {|promotion| promotion.credits_count < promotion.usage_limit}
          .pluck(:id)
      end
    end
  end
end
