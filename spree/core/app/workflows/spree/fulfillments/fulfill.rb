module Spree
  module Fulfillments
    # Marks a fulfillment as fulfilled, optionally only for some of the units
    # it holds.
    #
    # A fulfillment is the unit of shipping: it has one origin, one carrier and
    # one tracking number, so "half of it shipped" is not a state it can be in.
    # Shipping a subset therefore splits first — the chosen quantities move into
    # a new fulfillment which is the one that ships, and the remainder stays
    # behind, still open. That is what a merchant means by a partial shipment,
    # and it keeps every fulfillment honest about what is actually in the box.
    #
    # Passing no +items+ fulfills the whole thing, which is the common case and
    # the historic behavior.
    #
    # In the workflow tier because the split and the fulfillment have to happen
    # together or not at all: a split that succeeded while the fulfillment
    # failed would leave the order carrying a phantom fulfillment nobody asked
    # for. The state machine stays the low-level mechanic underneath — this
    # workflow decides *what* ships, the machine still decides whether the
    # transition is legal.
    class Fulfill < Spree::Workflow
      hooks :validate, :after_fulfill

      # The fulfillment that actually shipped. For a partial shipment this is
      # the newly split fulfillment, NOT the one passed in — callers rendering
      # a response want the shipped one.
      attr_reader :fulfillment

      # @param fulfillment [Spree::Fulfillment] the fulfillment to ship from
      # @param items [Array<Hash>, nil] `[{ line_item: Spree::LineItem, quantity: Integer }]`
      #   to ship; nil or empty fulfills every unit the fulfillment holds
      # @param tracking [String, nil] carrier tracking number or full tracking URL,
      #   stored on the fulfillment that ships
      # @param notify_customer [Boolean] whether the shipment email goes out;
      #   false suppresses it for this dispatch only
      # @return [Spree::ServiceModule::Result] the fulfilled fulfillment on success
      def perform(fulfillment:, items: nil, tracking: nil, notify_customer: true)
        super

        @source = fulfillment
        @requested = normalize_requested(items)

        # Veto point — cut-off windows, 3PL capacity, per-location policy.
        # Before anything is written: a rejection touches nothing.
        run_hooks :validate

        step :ensure_fulfillable

        ApplicationRecord.transaction do
          step :split_off_requested_units
          step :unstock_if_resuming_from_canceled
          step :apply_tracking
          step :mark_fulfilled
        end

        run_hooks :after_fulfill
        success(@fulfillment.reload)
      end

      private

      # Drops entries asking for nothing, so `[{quantity: 0}]` means "ship
      # everything" the same way an omitted list does rather than splitting off
      # an empty fulfillment.
      def normalize_requested(items)
        return [] if items.blank?

        items.filter_map do |item|
          quantity = item[:quantity].to_i
          { line_item: item[:line_item], quantity: quantity } if quantity.positive?
        end
      end

      def ensure_fulfillable
        failure(@source, Spree.t('fulfillments.errors.cannot_fulfill')) unless @source.can_fulfill?

        ensure_requested_units_available
      end

      # Each requested quantity has to exist in *this* fulfillment. Without
      # this the split would silently pull units out of a sibling fulfillment,
      # shipping goods the merchant did not select.
      def ensure_requested_units_available
        return if @requested.empty?

        available = @source.fulfillment_items.group(:line_item_id).sum(:quantity)

        @requested.each do |item|
          held = available[item[:line_item].id].to_i
          next if item[:quantity] <= held

          failure(
            @source,
            Spree.t('fulfillments.errors.not_in_fulfillment',
                    item: item[:line_item].prefixed_id, requested: item[:quantity], available: held)
          )
        end
      end

      # Reuses the create workflow rather than re-implementing unit moving:
      # creating a fulfillment at the same origin with the requested items is
      # exactly a split, and Create already handles the stock bookkeeping,
      # partial-quantity moves and draining of emptied sources.
      def split_off_requested_units
        @fulfillment = @source
        return if @requested.empty? || ships_everything?

        result = Spree.fulfillment_create_workflow.call(
          order: @source.order,
          stock_location: @source.stock_location,
          items: @requested,
          delivery_method: @source.delivery_method
        )

        failure(@source, result.error) unless result.success?

        @fulfillment = result.value
      end

      # Requesting every unit the fulfillment holds is a whole shipment wearing
      # a partial shipment's clothes. Splitting there would drain the source
      # and destroy it, which needlessly changes the fulfillment's number.
      def ships_everything?
        held = @source.fulfillment_items.group(:line_item_id).sum(:quantity)
        requested = @requested.to_h { |item| [item[:line_item].id, item[:quantity]] }

        held.all? { |line_item_id, quantity| requested[line_item_id].to_i >= quantity }
      end

      # A canceled fulfillment already put its units back on the shelf, so
      # shipping it directly has to take them off again — the state machine
      # allows canceled -> fulfilled precisely so goods that went out anyway
      # can be recorded. Previously the resume callback covered this; it is an
      # explicit step now that the callbacks are gone.
      def unstock_if_resuming_from_canceled
        return unless @source.canceled?

        @fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?

          @fulfillment.stock_location.unstock(item.variant, item.quantity, @fulfillment)
        end
      end

      # Written before the transition so the provider's own tracking lookup
      # (run_provider_create_fulfillment) sees an admin-entered number and
      # leaves it alone, and so the shipment email carries it.
      #
      # update_columns, not update! — Fulfillment#update! is a legacy override
      # taking the order and recomputing status, which would fire after_fulfill
      # ahead of the transition.
      def apply_tracking
        return if tracking.blank?

        @fulfillment.update_columns(tracking: tracking.to_s.squish, updated_at: Time.current)
      end

      # The suppression flag rides on the record because the event is published
      # from an after_transition callback, which takes no arguments.
      def mark_fulfilled
        @fulfillment.notify_customer = notify_customer
        @fulfillment.fulfill!
      rescue StateMachines::InvalidTransition => e
        failure(@fulfillment, e.message)
      end
    end
  end
end
