module Spree
  module Carts
    # Divides the paid draft order into one order per seller, under a group.
    #
    # Called by {Spree::Carts::Complete} when a checkout spans more than one
    # partition. The order this receives is the one the completion already
    # built and took payment against, holding the whole basket: this narrows it
    # to its own seller's items and moves the rest onto new sibling orders.
    #
    # Moving rather than re-copying is deliberate. Every line item, fulfillment
    # and typed money row was costed once, during completion, inside the lock —
    # re-deriving any of it here would ask the pricing and tax engines a
    # question whose answer is already recorded, and risk a different one. The
    # rows travel; only their owner changes.
    #
    # Per-seller totals are then computed independently, never prorated down
    # from the basket. The one exception is money that was never attached to an
    # item — an order-level fee such as a payment surcharge — which is
    # apportioned by item value, because there is nothing else to attach it to.
    class SplitBySeller
      prepend Spree::ServiceModule::Base

      # What a sibling order inherits from the order the checkout was taken
      # against — the facts about the purchase itself, which are true of every
      # order it produced.
      #
      # Deliberately an allowlist rather than an `except`: money columns, the
      # cart link, placement timestamps and the number are all per-order, and a
      # blocklist would carry every future column onto siblings by default.
      # Adding a column here is a decision that it describes the checkout
      # rather than one seller's part of it.
      CARRIED_TO_SIBLING = %w[
        email currency locale market_id channel_id company_id
        customer_id token accept_marketing preferred_stock_location_id
        customer_note last_ip_address po_number payment_terms
      ].freeze

      # @param cart [Spree::Cart]
      # @param order [Spree::Order] the paid draft order, adopted as the
      #   group's first child rather than replaced — it is the record the
      #   payment was taken against
      # @param partitions [Array<Spree::Carts::SellerPartition>] ordered, first
      #   party first
      # @return [Spree::ServiceModule::Result] value is the Spree::OrderGroup
      def call(cart:, order:, partitions:)
        group = nil
        # Every apportionment here divides money in this one currency.
        @currency = order.currency

        ApplicationRecord.transaction do
          group = build_group(cart, order)
          first, *rest = partitions

          orders = [adopt_order(order, group, first)]
          rest.each_with_index do |partition, index|
            orders << hand_off(order, group, partition, index + 2)
          end

          distribute_order_level_fees(order, orders, partitions)
          orders.each do |child|
            resum_totals(child)
            restate_deposit_base(child)
          end
        end

        # Handed over with the children loaded: everything downstream reads
        # them — placement, tax filing, the response — and the group's own
        # figures are summed from them.
        group.orders.load

        success(group)
      end

      private

      # The group takes the number the order was already given, so the customer
      # keeps the reference they saw at checkout, and the children number off
      # it: R1001-1, R1001-2. The cart_id moves up too — the group is what that
      # cart completed into, and it becomes the replay anchor.
      def build_group(cart, order)
        order.update_columns(cart_id: nil)

        group = cart.store.order_groups.create!(
          cart: cart,
          customer: cart.customer,
          number: order.number,
          currency: cart.currency,
          email: cart.email,
          token: cart.token,
          ship_address: cart.ship_address&.snapshot,
          bill_address: cart.bill_address&.snapshot
        )
        group
      end

      # Files the paid order under the group as its first child. Its own
      # partition's rows simply stay where they are.
      def adopt_order(order, group, partition)
        order.update_columns(
          order_group_id: group.id,
          seller_id: partition.seller_id,
          number: "#{group.number}-1"
        )
        order.reload
      end

      # Builds a sibling and moves one partition's rows onto it. Ownership is
      # rewritten in place — update_columns rather than saves — so nothing
      # re-runs the callbacks that would recost a line item whose price was
      # settled during completion.
      def hand_off(source_order, group, partition, index)
        sibling = source_order.store.orders.create!(
          source_order.attributes.slice(*CARRIED_TO_SIBLING).merge(
            'order_group_id' => group.id,
            'seller_id' => partition.seller_id,
            'number' => "#{group.number}-#{index}",
            'status' => 'draft',
            # Copies, not the same rows: each order has to be able to have its
            # address corrected without moving a sibling's parcel.
            'ship_address' => source_order.ship_address&.snapshot,
            'bill_address' => source_order.bill_address&.snapshot
          )
        )

        line_item_ids = move_line_items(source_order, sibling, partition)
        move_stock_reservations(sibling, line_item_ids)
        divided = move_fulfillments(source_order, sibling, line_item_ids)
        move_typed_lines(sibling, line_item_ids, divided)
        copy_promotions(source_order, sibling)
        copy_tax_identifier(source_order, sibling)
        copy_po_document(source_order, sibling)

        sibling.reload
      end

      # @return [Array<Integer>] the ids of the line items now owned by the sibling
      def move_line_items(source_order, sibling, partition)
        scope = source_order.line_items.where(seller_id: partition.seller_id)
        ids = scope.pluck(:id)
        Spree::LineItem.where(id: ids).update_all(order_id: sibling.id, updated_at: Time.current)
        ids
      end

      # The stock a line item is holding follows it, or the child that keeps
      # the item would release someone else's reservation on completion and
      # leave its own held until they expire.
      def move_stock_reservations(sibling, line_item_ids)
        Spree::StockReservation.where(line_item_id: line_item_ids).
          update_all(order_id: sibling.id, updated_at: Time.current)
      end

      # A fulfillment follows its items. One holding items from several
      # partitions is split in two — the moving items get a new fulfillment on
      # the sibling carrying the same delivery choice, and the rest stay put —
      # which keeps a parcel's contents and the rate quoted for it together.
      #
      # @return [Hash{Integer => Array(Integer, Array<Integer>)}] original
      #   fulfillment id → its replacement's id and the weights the two halves
      #   divide by, for the parcels that had to be divided. Whole-parcel moves
      #   are absent: they keep their id, so the rows hanging off them need no
      #   rewriting. The weights travel because everything a divided parcel
      #   apportions — its cost, its tax, its discounts — divides by the same
      #   two numbers, and they cost a query each to work out.
      def move_fulfillments(source_order, sibling, line_item_ids)
        fulfillments = source_order.fulfillments.reload.includes(fulfillment_items: :line_item).to_a

        fulfillments.each_with_object({}) do |fulfillment, divided|
          items = fulfillment.fulfillment_items.to_a
          moving = items.select { |item| line_item_ids.include?(item.line_item_id) }
          next if moving.empty?

          if moving.size == items.size
            fulfillment.update_columns(order_id: sibling.id, address_id: sibling.ship_address_id)
            Spree::FulfillmentItem.where(id: moving.map(&:id)).update_all(order_id: sibling.id)
            next
          end

          replacement = clone_fulfillment(fulfillment, sibling)
          Spree::FulfillmentItem.where(id: moving.map(&:id)).
            update_all(fulfillment_id: replacement.id, order_id: sibling.id)

          restate_freight_summaries(fulfillment, replacement)

          weights = [items - moving, moving].map { |half| to_minor_units(items_value(half)) }
          divide_delivery_cost(fulfillment, replacement, weights)
          divided[fulfillment.id] = [replacement.id, weights]
        end
      end

      # One parcel becoming two must not charge for delivery twice: the
      # customer was quoted one cost for one shipment, so it is divided between
      # the halves by what each now carries rather than copied onto both.
      #
      # This is the honest reading of a quote that no longer describes what is
      # being shipped. A marketplace that wants each seller to be quoted
      # separately gets that by giving sellers their own delivery methods, which
      # packs their goods into their own parcel from the start — at which point
      # nothing here has to divide anything.
      def divide_delivery_cost(original, replacement, weights)
        total_cost = original.cost.to_d
        return if total_cost.zero?

        # Both halves worth nothing — a free sample boxed with paid goods —
        # still has to divide the charge, or the cost stays whole on each and
        # the customer is billed for delivery twice. Splitting it evenly is
        # the only honest answer when value cannot say.
        weights = [1, 1] if weights.sum <= 0

        shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(to_minor_units(total_cost), weights)

        apply_divided_cost(original, from_minor_units(shares[0]))
        apply_divided_cost(replacement, from_minor_units(shares[1]))
      end

      # The rate is written down with the parcel. A fulfillment's cost is
      # restated from its selected rate whenever its amounts are refreshed, so
      # leaving the rate at the undivided figure would quietly restore the full
      # delivery charge on both halves the next time anything touched them.
      def apply_divided_cost(fulfillment, cost)
        fulfillment.selected_delivery_rate&.update_columns(cost: cost, updated_at: Time.current)
        fulfillment.update_columns(cost: cost, updated_at: Time.current)
      end

      # @param items [Array<Spree::FulfillmentItem>]
      # @return [BigDecimal] what those items are worth
      def items_value(items)
        items.sum do |item|
          line_item = item.line_item
          next 0 if line_item.nil? || line_item.quantity.to_i.zero?

          line_item.amount * item.quantity.to_d / line_item.quantity
        end
      end

      def clone_fulfillment(fulfillment, sibling)
        attributes = fulfillment.attributes.except('id', 'cart_id', 'number', 'created_at', 'updated_at')
        replacement = sibling.fulfillments.create!(
          attributes.merge('order_id' => sibling.id, 'address_id' => sibling.ship_address_id)
        )

        if (selected = fulfillment.selected_delivery_rate)
          rate_attributes = selected.attributes.except('id', 'created_at', 'updated_at')
          replacement.delivery_rates.create!(
            rate_attributes.merge('fulfillment_id' => replacement.id)
          )
        end

        replacement
      end

      # A freight summary describes one consignment's load, so neither half of a
      # divided parcel may keep the whole shipment's cartons and cubic meters —
      # two forwarders would each be asked to book the entire load.
      #
      # Restated only once the items have moved: read any earlier, both halves
      # describe what they held before the split, and the new one holds nothing
      # at all.
      def restate_freight_summaries(*fulfillments)
        fulfillments.each do |fulfillment|
          rate = fulfillment.reload.selected_delivery_rate
          next if rate.nil?

          metadata = rate.metadata
          next if metadata.blank? || metadata['freight_summary'].blank?

          summary = Spree::FreightSummary.build(fulfillment.to_package.contents)
          rate.update_columns(metadata: metadata.merge('freight_summary' => summary.as_json))
        end
      end

      # Tax lines, discounts and fees follow whatever they hang off. Rows
      # attached to nothing are order-level and are apportioned separately.
      #
      # A parcel that moved whole keeps its id, so its rows move with a plain
      # re-point. A parcel that was divided leaves its rows behind on an
      # original that now carries only part of the goods — they have to be
      # divided too, or the source over-taxes a halved parcel and the sibling
      # ships with no delivery tax at all.
      #
      # @param divided [Hash{Integer => Array(Integer, Array<Integer>)}] what
      #   {#move_fulfillments} reported about the parcels it had to divide
      def move_typed_lines(sibling, line_item_ids, divided = {})
        moved_fulfillment_ids = sibling.fulfillments.reload.pluck(:id) - divided.values.map(&:first)

        [Spree::TaxLine, Spree::Discount, Spree::Fee].each do |klass|
          klass.where(line_item_id: line_item_ids).update_all(order_id: sibling.id, updated_at: Time.current)

          next unless klass.column_names.include?('fulfillment_id')

          klass.where(fulfillment_id: moved_fulfillment_ids).update_all(order_id: sibling.id, updated_at: Time.current)
          divided.each do |original_id, (replacement_id, weights)|
            divide_fulfillment_rows(klass, original_id, replacement_id, weights, sibling)
          end
        end
      end

      # Splits one parcel's money rows between the two halves it became, by
      # what each half now carries — the same basis its delivery cost was
      # divided on, so the tax still describes the charge.
      def divide_fulfillment_rows(klass, original_id, replacement_id, weights, sibling)
        return if weights.sum <= 0

        klass.where(fulfillment_id: original_id).find_each do |row|
          apportion_row(row, weights, [{}, { 'order_id' => sibling.id, 'fulfillment_id' => replacement_id }])
        end
      end

      def copy_promotions(source_order, sibling)
        source_order.order_promotions.find_each do |order_promotion|
          sibling.order_promotions.find_or_create_by!(promotion_id: order_promotion.promotion_id)
        end
      end

      # The buyer's tax registration is a snapshot, and each order has to be
      # explainable on its own — so every child receives a copy of it.
      def copy_tax_identifier(source_order, sibling)
        identifier = source_order.tax_identifier
        return if identifier.nil?

        attributes = identifier.attributes.except('id', 'owner_type', 'owner_id',
                                                  'created_at', 'updated_at')
        sibling.create_tax_identifier!(attributes)
      end

      # The PO number rides along in CARRIED_TO_SIBLING, so the document behind
      # it has to as well — otherwise a buyer whose checkout splits sees their
      # reference on every order and the paperwork on only one. The same blob,
      # like the completion copy.
      def copy_po_document(source_order, sibling)
        return unless source_order.po_document.attached?

        return if sibling.po_document.attach(source_order.po_document.blob)

        raise ActiveRecord::RecordInvalid, sibling
      end

      # An order-level fee was charged for the checkout as a whole, so it is
      # apportioned across the children by what each is worth. Largest-remainder
      # so the shares add back up to what the customer was charged, and the
      # fee's own tax follows the share it was charged on.
      def distribute_order_level_fees(source_order, orders, partitions)
        fees = Spree::Fee.where(order_id: source_order.id, line_item_id: nil, fulfillment_id: nil).to_a
        return if fees.empty?

        weights = partitions.map { |partition| to_minor_units(partition.item_total) }
        return if weights.sum <= 0

        fees.each { |fee| distribute_fee(fee, orders, weights) }
      end

      def distribute_fee(fee, orders, weights)
        targets = orders.map { |order| { 'order_id' => order.id } }
        placed_fees = apportion_row(fee, weights, targets)

        Spree::TaxLine.where(fee_id: fee.id).find_each do |tax_line|
          # A fee's tax follows the share it was charged on, so each copy is
          # attached to the fee that landed on the same order.
          tax_targets = placed_fees.map do |placed_fee|
            { 'order_id' => placed_fee&.order_id, 'fee_id' => placed_fee&.id } if placed_fee
          end

          apportion_row(tax_line, weights, tax_targets)
        end
      end

      # Divides one money row across several owners.
      #
      # The row itself takes the first share — restating it rather than
      # destroying and recreating keeps whatever else points at it — and each
      # remaining share becomes a copy carrying that owner's attributes. Shares
      # come from largest-remainder, so together they still add up to the
      # amount the customer was charged.
      #
      # @param targets [Array<Hash, nil>] the attributes each share is written
      #   with, index-aligned with the weights; a nil target skips its share
      # @return [Array<ActiveRecord::Base, nil>] the row now holding each share
      def apportion_row(row, weights, targets)
        shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(to_minor_units(row.amount), weights)

        shares.each_with_index.map do |share, index|
          target = targets[index]
          next if target.nil?
          next if index.positive? && share.zero?

          placed = index.zero? ? row : copy_row(row, target)
          placed.update_columns(amount: from_minor_units(share), updated_at: Time.current)
          placed
        end
      end

      # @return [ActiveRecord::Base] a new row like this one, on another owner
      def copy_row(row, attributes)
        row.class.create!(
          row.attributes.except('id', 'cart_id', 'created_at', 'updated_at').merge(attributes)
        )
      end

      # Each child re-sums the rows it now owns. Deliberately the totals
      # workflow rather than arithmetic here: it is the single home for what an
      # order's money adds up to, and a second implementation would be a second
      # answer.
      #
      # resum_only, because the children are still drafts and would otherwise
      # be money-regenerated: the promotion adjuster would delete the discounts
      # just moved onto them and recompute against one seller's subset (an
      # order-level threshold the whole basket met, most children would fail),
      # and the tax provider would delete the moved tax lines and re-derive them
      # from today's rates. The checkout already answered both questions against
      # the whole basket, and the customer has already paid that answer.
      # The deposit percentage was agreed for the whole basket, but each child
      # is billed on its own. Left alone, every sibling would measure its
      # deposit against the basket's total — the adopted first child included,
      # since it keeps the base it was completed with.
      def restate_deposit_base(order)
        terms = order.payment_terms
        return if terms.blank? || terms['base_total'].blank?

        order.update_columns(payment_terms: terms.merge('base_total' => order.reload.total.to_s))
      end

      def resum_totals(order)
        Spree.order_recalculate_totals_workflow.call(order: order.reload, resum_only: true)
      end

      # Apportionment works in the currency's smallest whole unit, so shares
      # divide exactly and add back up to the charge they came from.
      def to_minor_units(amount)
        Spree::Money::Rounding.to_minor_units(amount, @currency)
      end

      def from_minor_units(units)
        Spree::Money::Rounding.from_minor_units(units, @currency)
      end
    end
  end
end
