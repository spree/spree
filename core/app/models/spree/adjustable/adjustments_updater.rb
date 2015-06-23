module Spree
  module Adjustable
    class AdjustmentsUpdater

      def self.update(adjustable)
        new(adjustable).update
      end

      def initialize(adjustable)
        @adjustable = adjustable
        adjustable.reload if shipment? && adjustable.persisted?
      end

      def update
        return unless @adjustable.persisted?

        totals = { adjustment_total: 0 }
        adjusters.each do |klass|
          klass.adjust(@adjustable, totals)
        end

        persist_totals totals
      end

      private

      def persist_totals totals
        attributes = totals
        attributes[:updated_at] = Time.now
        @adjustable.update_columns(totals)
      end

      def shipment?
        @adjustable.is_a?(Shipment)
      end

      def adjusters
        [Spree::Adjustable::Adjuster::Promo, Spree::Adjustable::Adjuster::Tax]
        #Rails.application.config.spree.adjustable_adjusters
      end
    end
  end
end
