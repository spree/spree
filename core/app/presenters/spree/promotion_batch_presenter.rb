module Spree
  class PromotionBatchPresenter
    def initialize(promotion_batch)
      @promotion_batch = promotion_batch
    end

    def call
      {
        template_promotion_name_id: template_promotion_name_id,
        model_name_id: model_name_id
      }
    end

    private

    attr_reader :promotion_batch

    def template_promotion_name_id
      return "" unless promotion_batch.template_promotion

      base = promotion_batch.template_promotion.name
      addon = promotion_batch.template_promotion_id.to_s
      base + ' # ' + addon
    end

    def model_name_id
      base = promotion_batch.class.name.demodulize
      addon = promotion_batch.id.to_s
      base + ' # ' + addon
    end
  end
end
