module Spree
  module Promotions
    class PopulatePromotionBatch
      TemplateNotFoundError = Class.new(StandardError)

      def initialize(batch_id, options = {})
        @batch_id = batch_id
        @options = options
      end

      def call
        validate_template_presence!

        size.times do
          DuplicatePromotionJob.perform_later(template_promotion_id: template_promotion_id, batch_id: batch_id, options: options.except(:batch_size))
        end
      end

      private

      attr_accessor :options
      attr_reader :batch_id

      def validate_template_presence!
        raise TemplateNotFoundError, Spree.t('template_not_found') unless template_promotion_id
      end

      def size
        options[:batch_size]
      end

      def template_promotion_id
        PromotionBatch.find(batch_id).template_promotion_id
      end
    end
  end
end
