module Spree
  module PromotionBatches
    class PromotionCodesImporter
      Error = Class.new(StandardError)

      ALLOWED_FILE_TYPES = %w(text/csv).freeze

      def initialize(file:, promotion_batch_id:)
        @content_type = file&.content_type
        @content = file&.read.to_s
        @promotion_batch = find_promotion_batch(promotion_batch_id)
      end

      def call
        validate_file!
        validate_promotion_batch!

        parsed_rows.each do |parsed_row|
          Spree::Promotions::DuplicatePromotionJob
            .perform_later(template_promotion_id: @promotion_batch.template_promotion_id, batch_id: @promotion_batch.id, code: parsed_row)
        end
      end

      private

      def find_promotion_batch(id)
        Spree::PromotionBatch.find(id)
      end

      def validate_file!
        raise Error, Spree.t('invalid_file') unless file_valid
      end

      def file_valid
        file_type_correct? && file_not_empty?
      end

      def file_type_correct?
        @content_type.in?(ALLOWED_FILE_TYPES)
      end

      def file_not_empty?
        parsed_rows.present?
      end

      def validate_promotion_batch!
        raise Error, Spree.t('no_template_promotion') unless batch_validation_condition
      end

      def batch_validation_condition
        @promotion_batch.template_promotion_id
      end

      def parsed_rows
        CSV.new(rows, headers: false).read.map(&:first)
      end

      def rows
        @content.lines.join
      end
    end  
  end
end
