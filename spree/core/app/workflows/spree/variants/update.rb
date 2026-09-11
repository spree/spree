module Spree
  module Variants
    # Updates a variant, reconciling the option values, prices and stock
    # levels the payload carries (see Spree::Variants::NestedAttributes —
    # prices replace, stock levels and options upsert).
    #
    # Handlers reading `variant.changes` in :validate see the pending edit
    # before it is written.
    class Update < Spree::Workflow
      include Spree::Variants::NestedAttributes

      hooks :validate, :after_update

      # @param variant [Spree::Variant]
      # @param attributes [Hash] may carry `options`, `prices`, `stock_levels`
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:, attributes: {})
        super

        step :assign_attributes
        step :refuse_review_status_write
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_variant
          step :apply_nested_attributes
          run_hooks :after_update
        end

        success(variant)
      end

      private

      def assign_attributes
        attrs = attributes.to_h.with_indifferent_access
        @status_in_payload = attrs.key?(:status)

        @options_params = attrs.delete(:options)
        @prices_params = attrs.delete(:prices)
        @stock_levels_params = attrs.delete(:stock_levels) || attrs.delete(:stock_levels_attributes)

        variant.assign_attributes(attrs)
      end

      # An offer's status is a decision, and a decision belongs to the review
      # workflows — they are what record who made it and settle the submission
      # row. A plain status write would put a seller's offer on sale with
      # nobody's name against it, so it refuses
      # (docs/plans/6.0-seller-master-catalog-listings.md).
      #
      # Guarded on the row being an offer rather than on where it was: a
      # `draft` or `archived` offer is not in review, but flipping one to
      # `active` is exactly the write this exists to stop. `Variants::Activate`
      # refuses an offer for the same reason.
      #
      # Only what this call asked for: a caller that assigns attributes itself
      # and hands over an already-dirty record must not be refused for an edit
      # it did not make.
      def refuse_review_status_write
        return unless @status_in_payload
        return unless variant.status_changed?
        return unless variant.offer? || variant.status_was.in?(Spree::Variant::REVIEW_STATUSES)

        reject!(:status_decided_by_review, message: I18n.t('activerecord.errors.models.spree/variant.attributes.base.status_decided_by_review'))
      end

      def save_variant
        failure(variant) unless variant.save
      end

      def apply_nested_attributes
        apply_options(variant, @options_params)
        apply_prices(variant, @prices_params)
        apply_stock_levels(variant, @stock_levels_params)
      end
    end
  end
end
