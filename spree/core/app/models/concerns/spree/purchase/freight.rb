module Spree
  module Purchase
    # The logistics rollup a freight forwarder quotes against — units,
    # cartons, pallets, cubic meters and gross weight — shared by
    # Spree::Cart and Spree::Order.
    #
    # A cart computes it live, because until checkout picks a rate there is
    # nothing to freeze and the buyer is still changing what they are buying.
    # An order reads only the copy the freight provider froze onto the rates
    # it actually shipped under, and never falls back to the live catalog: a
    # carton size corrected next month must not rewrite what last month's
    # container held. An order that shipped by parcel therefore reports no
    # freight summary at all. Same doctrine as the duty snapshot
    # (docs/plans/6.0-duties-and-custom-fees.md).
    module Freight
      extend ActiveSupport::Concern

      # @return [Spree::FreightSummary, nil] nil when nothing here is
      #   measurable as freight
      def freight_summary
        return @freight_summary if defined?(@freight_summary)

        summary = build_freight_summary
        # Assigned on every path, including the empty one: a retail cart is
        # where this is asked most and answered "nothing", and a conditional
        # assignment would leave that case unmemoized — walking every line
        # item's variant again on each call, which is the opposite of what
        # memoizing is for.
        @freight_summary = (summary unless summary.nil? || summary.empty?)
      end

      # Dropped on reload, so a cart whose items changed in the same request
      # rolls up again rather than answering from the load it had before.
      def reload(*)
        remove_instance_variable(:@freight_summary) if defined?(@freight_summary)
        super
      end

      private

      # A cart rolls its own line items up; an order reads what was frozen.
      #
      # @return [Spree::FreightSummary, nil]
      def build_freight_summary
        Spree::FreightSummary.for_purchase(self)
      end
    end
  end
end
