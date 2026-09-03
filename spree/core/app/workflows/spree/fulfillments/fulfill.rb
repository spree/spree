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
    # workflow decides *what* ships and whether shipping it is allowed.
    class Fulfill < Spree::Workflow
      hooks :validate, :after_fulfill

      # The fulfillment that actually shipped. For a partial shipment this is
      # the newly split fulfillment, NOT the one passed in — callers rendering
      # a response want the shipped one.
      attr_reader :fulfillment

      # @param fulfillment [Spree::Fulfillment] the fulfillment to ship from
      # @param items [Array<Hash>, nil] `[{ line_item: Spree::LineItem, quantity: Integer }]`
      #   to ship; nil or empty fulfills every unit the fulfillment holds
      # @param tracking [String, nil] carrier tracking number or full tracking URL —
      #   the one-parcel shortcut: recorded as the primary Spree::Delivery of
      #   the fulfillment that ships
      # @param tracking_carrier [String, nil] which carrier the number belongs
      #   to (free text; a Spree.tracking_carriers key gets a badge and URL);
      #   detected from the number when omitted
      # @param notify_customer [Boolean] whether the shipment email goes out;
      #   false suppresses it for this dispatch only
      # @param force [Boolean] dispatch even when the order is unpaid or holds
      #   backordered units. The merchant's call to make — staff shipping
      #   against an invoice is ordinary trade, and the old pending/ready
      #   statuses made it impossible to express.
      # @return [Spree::ServiceModule::Result] the fulfilled fulfillment on success
      def perform(fulfillment:, items: nil, tracking: nil, tracking_carrier: nil, notify_customer: true, force: false)
        super

        @source = fulfillment
        @requested = normalize_requested(items)

        # Veto point — cut-off windows, 3PL capacity, per-location policy.
        # Before anything is written: a rejection touches nothing.
        run_hooks :validate

        step :ensure_fulfillable

        # The split has to land before the provider is involved: the label is
        # for the actual parcel, and a partial shipment's parcel only exists
        # after the split.
        ApplicationRecord.transaction do
          step :split_off_requested_units
          step :apply_tracking
        end

        # The label is bought BEFORE the fulfillment is declared fulfilled —
        # the physical order of a warehouse (print the label, stick it on the
        # box, hand it over), and the ordering that lets the shipped email
        # carry the tracking number the provider discovered instead of racing
        # it. No-op when a label was already bought through
        # Spree::Fulfillments::PurchaseLabel (the flow where a failure is
        # loud), or when the provider has no dispatch mechanics (Manual). A
        # failure here still degrades to "no label yet" — a carrier outage
        # must never stop a merchant recording a parcel that physically left.
        # Network I/O, so never in a transaction.
        external_step :purchase_label
        external_step :tell_provider_it_shipped

        ApplicationRecord.transaction do
          step :ship_allocated_units
          step :mark_fulfilled
          step :capture_payment_if_configured
        end

        step :roll_up_order_status

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

        ensure_order_placed
        ensure_ready_to_hand_over
        ensure_shelf_can_cover_dispatch
        ensure_requested_units_available
      end

      # Not skippable by force. Forcing past an unpaid invoice is ordinary
      # trade; a draft is not a commitment yet — nothing has been agreed, so
      # there is nothing to hand over. Completing the draft is the way out.
      def ensure_order_placed
        return unless @source.order&.draft?

        failure(@source, Spree.t('fulfillments.errors.order_draft'))
      end

      # What the pending/ready statuses used to encode, asked once at the
      # moment it matters instead of being recomputed onto every fulfillment
      # whenever the order changed. A validate hook can wave either rule
      # through — staff dispatching against an unpaid invoice is a normal
      # merchant decision, and it was impossible while the status itself was
      # derived from payment.
      def ensure_ready_to_hand_over
        return if force

        order = @source.order
        return if order.nil?

        if @source.fulfillment_items.any?(&:backordered?)
          failure(@source, Spree.t('fulfillments.errors.backordered_units'))
        end

        return if order.paid?

        # Charging later is a deliberate choice, so an authorized-but-uncaptured
        # order is ready to hand over: on dispatch the money is taken below,
        # and manual means staff have taken charge of collecting it.
        #
        # Every pending payment has to defer, not just one — on a mixed-tender
        # order a single deferred payment must not wave through a sibling that
        # should have been collected at checkout.
        pending = order.pending_payments
        return if pending.any? && pending.all? { |payment| payment.payment_method&.capture_at_checkout? == false }

        failure(@source, Spree.t('fulfillments.errors.order_not_paid'))
      end

      # The shelf has to be able to cover what is about to leave it. A dispatch
      # that would take it below zero is one of two things, and only the
      # merchant can say which: a ledger error, fixed with a stock adjustment
      # and then shipped normally, or goods the warehouse knows it does not
      # have, which is what force is for.
      #
      # Refused here rather than at the stock write so it renders as a 422 the
      # merchant can act on, instead of a validation exception surfacing from
      # inside the dispatch transaction.
      def ensure_shelf_can_cover_dispatch
        return if force

        quantities = dispatch_quantity_by_variant
        return if quantities.empty?

        variants = Spree::Variant.with_deleted.where(id: quantities.keys).index_by(&:id)

        quantities.each do |variant_id, quantity|
          stock_level = @source.stock_location.stock_level(variant_id)
          next if stock_level.nil? || stock_level.count_on_hand >= quantity

          failure(
            @source,
            Spree.t('fulfillments.errors.insufficient_stock_on_hand',
                    item: variants[variant_id]&.name,
                    on_hand: stock_level.count_on_hand,
                    requested: quantity)
          )
        end
      end

      # What each variant will actually ship: its outstanding promise, capped
      # by what this dispatch covers. A partial dispatch splits first and the
      # split carries min(promise, moved quantity), so the two agree.
      #
      # @return [Hash{Integer => Integer}]
      def dispatch_quantity_by_variant
        held = @source.fulfillment_items.group(:variant_id).sum(:quantity)

        allocated = @source.allocated_quantities
        return {} if allocated.empty?

        wanted =
          if @requested.empty?
            held
          else
            @requested.each_with_object(Hash.new(0)) do |item, totals|
              totals[item[:line_item].variant_id] += item[:quantity]
            end
          end

        allocated.each_with_object({}) do |(variant_id, promised), totals|
          quantity = [promised, wanted[variant_id].to_i].min
          totals[variant_id] = quantity if quantity.positive?
        end
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

      # The shelf empties when the parcel leaves, for the units this
      # fulfillment actually holds a promise for. A fulfillment created before
      # typed movements holds none — its stock left at placement under the old
      # model — so it ships without a movement and is not decremented twice.
      def ship_allocated_units
        allocated = @fulfillment.allocated_quantities
        return if allocated.empty?

        @fulfillment.manifest.each do |item|
          quantity = [allocated[item.variant.id].to_i, item.quantity].min
          next unless quantity.positive?

          @fulfillment.stock_location.unstock(item.variant, quantity, @fulfillment, force: force)
        end
      end

      # Recorded before the provider is asked, so a label purchase sees the
      # admin-entered number and binds to it rather than minting a second
      # consignment, and so the shipment email carries it. The primary
      # delivery is created, or its number corrected.
      def apply_tracking
        return if tracking.blank?

        primary = @fulfillment.primary_delivery
        if primary
          attributes = { tracking_number: tracking.to_s.squish }
          attributes[:carrier] = tracking_carrier if tracking_carrier.present?
          attributes[:status] = 'pending' if attributes[:tracking_number] != primary.tracking_number
          primary.update!(attributes)
          return
        end

        result = Spree.delivery_create_service.call(
          owner: @fulfillment, tracking_number: tracking, carrier: tracking_carrier
        )
        failure(@source, result.error.to_s) if result.failure?
      end

      # The suppression flag rides on the record because the event publisher
      # reads it when building the event metadata.
      def mark_fulfilled
        @fulfillment.notify_customer = notify_customer
        # Stock in hand always leaves; a forced dispatch takes backordered
        # units with it, because the parcel has physically gone.
        shippable = force ? %w[on_hand backordered] : %w[on_hand]
        @fulfillment.fulfillment_items.where(status: shippable).update_all(status: 'shipped', updated_at: Time.current)
        # update_all leaves the loaded association holding the old statuses,
        # which later steps and hook handlers would read.
        @fulfillment.fulfillment_items.reset
        @fulfillment.update!(status: 'fulfilled', fulfilled_at: Time.current)
        @fulfillment.publish_fulfillment_fulfilled_event
      end

      # Dispatch is the trigger for taking the money on payments whose method
      # charges on dispatch; the fulfillment decides which ones qualify.
      def capture_payment_if_configured
        @fulfillment.process_order_payments
      end

      # A label-generating provider is asked for the label unless one is
      # already active; the outcome is the label's own affair — a failure
      # here is reported and the parcel still ships.
      def purchase_label
        return unless @fulfillment.provider.class.generates_labels?
        return if @fulfillment.shipping_labels.active.exists?

        result = Spree.shipping_label_purchase_workflow.call(owner: @fulfillment)
        return if result.success?

        Rails.error.report(
          Spree::Core::LabelPurchaseFailed.new(result.error.to_s),
          context: { fulfillment_id: @fulfillment.id }, source: 'spree.fulfillments.fulfill'
        )
      end

      # Non-label dispatch — a 3PL pick, digital links. A provider whose
      # dispatch IS the label was already asked for it above, and asking it
      # again would buy a second one. Tracking the provider discovers becomes
      # the primary delivery unless an admin already typed one in — a human
      # who entered a number meant it.
      def tell_provider_it_shipped
        return if @fulfillment.provider.class.generates_labels?

        result = @fulfillment.provider.create_fulfillment(@fulfillment)
        return unless result.is_a?(Hash)

        new_tracking = result[:tracking_number].presence
        return if new_tracking.blank? || @fulfillment.tracking.present?

        Spree.delivery_create_service.call(
          owner: @fulfillment, tracking_number: new_tracking, tracking_url: result[:tracking_url]
        )
      end

      def roll_up_order_status
        @fulfillment.order&.update_statuses!
      end
    end
  end
end
