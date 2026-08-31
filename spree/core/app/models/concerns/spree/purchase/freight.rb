module Spree
  module Purchase
    # The logistics rollup a freight forwarder quotes against — units,
    # cartons, pallets, cubic meters and gross weight — shared by
    # Spree::Cart and Spree::Order.
    #
    # A cart computes it live, because until checkout picks a rate there is
    # nothing to freeze and the buyer is still changing what they are buying.
    # An order reads the copy the freight provider froze onto the rate it
    # actually shipped under, so a carton size corrected next month does not
    # rewrite what last month's container held. Same doctrine as the duty
    # snapshot (docs/plans/6.0-duties-and-custom-fees.md).
    module Freight
      extend ActiveSupport::Concern

      # @return [Spree::FreightSummary, nil] nil when nothing here is
      #   measurable as freight
      def freight_summary
        summary = frozen_freight_summary || Spree::FreightSummary.for_purchase(self)

        summary unless summary.nil? || summary.empty?
      end

      private

      # The summary a freight rate carried when it was quoted. Nil on carts
      # and on orders that shipped by parcel.
      #
      # @return [Spree::FreightSummary, nil]
      def frozen_freight_summary
        return unless is_a?(Spree::Order)

        fulfillments.filter_map { |fulfillment| fulfillment.selected_delivery_rate&.freight_summary }.first
      end
    end
  end
end
