module Spree
  module Purchase
    # The logistics rollup a freight forwarder quotes against — units,
    # cartons, pallets, cubic meters and gross weight — shared by
    # Spree::Cart and Spree::Order.
    #
    # Read only from what the freight provider froze onto the rates a
    # purchase ships under, never derived from the live catalog. Until a
    # freight rate is selected there is nothing to report, and a purchase
    # that ships by parcel reports nothing at all: a parcel carrier does not
    # read cubic meters. Once quoted, a carton size corrected next month must
    # not rewrite what this container held. Same doctrine as the duty
    # snapshot (docs/plans/6.0-duties-and-custom-fees.md).
    module Freight
      extend ActiveSupport::Concern

      # @return [Spree::FreightSummary, nil] nil unless a selected rate
      #   carries a frozen summary
      def freight_summary
        return @freight_summary if defined?(@freight_summary)

        summary = build_freight_summary
        # Assigned on every path, including the empty one: every retail
        # purchase answers "nothing", and a conditional assignment would leave
        # that case unmemoized — querying the fulfillments again on each call,
        # which is the opposite of what memoizing is for.
        @freight_summary = (summary unless summary.nil? || summary.empty?)
      end

      # Dropped on reload, so a purchase whose rate selection changed in the
      # same request reads again rather than answering from the load it had
      # before.
      def reload(*)
        remove_instance_variable(:@freight_summary) if defined?(@freight_summary)
        super
      end

      private

      # Only the consignments actually shipping: a canceled fulfillment keeps
      # its frozen summary, so counting it would report a re-allocated load
      # twice. Two freight consignments are still one load to the forwarder,
      # so they are merged rather than listed.
      def build_freight_summary
        summaries = fulfillments.valid.filter_map { |fulfillment| fulfillment.selected_delivery_rate&.freight_summary }
        return if summaries.empty?

        Spree::FreightSummary.merge(summaries)
      end
    end
  end
end
