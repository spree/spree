# frozen_string_literal: true

module Spree
  module Commissions
    # Writes an order's commission lines: one per sold item, plus one per
    # fulfillment when the rate charges delivery too.
    #
    # Runs once, at placement, and is idempotent — an order that already
    # carries commission is left exactly as it is. Both matter because the
    # lines are a settlement record: recomputing them later would let a rate
    # edit rewrite what a seller was already told they owed, and a replayed
    # placement would charge them twice.
    #
    # Lines are grouped by the seller each item was bought from, which is
    # `line_item.vendor_id` — the snapshot frozen when the order was placed,
    # not whoever owns the product today. Items with no seller are the
    # marketplace's own and are not commissioned.
    #
    # It runs inside the customer's checkout, so everything it reads is loaded
    # up front: the sellers, their billing addresses (the tax question is asked
    # against those), the products behind each line, and the order's
    # fulfillments — each once for the whole order rather than once per line.
    #
    # Swap through +Spree.commissions_commission_order_service+.
    class CommissionOrder
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @return [Array<Spree::CommissionLine>] the lines written, empty when
      #   there was nothing to commission
      def call(order:)
        return success([]) if order.commission_lines.exists?

        commissioned = order.line_items.
                       includes(vendor: :billing_address, variant: { product: :categories }).
                       select(&:vendor_id)
        return success([]) if commissioned.empty?

        rates = Spree::Commissions::ResolveRate.candidates_for(order.store)
        categories = Spree::Commissions::ResolveRate.categories_for(
          commissioned.map { |line_item| line_item.variant&.product }
        )
        deliveries = deliveries_by_vendor(order)
        lines = []

        Spree::CommissionLine.transaction do
          commissioned.group_by(&:vendor_id).each_value do |line_items|
            lines.concat(
              commission_vendor(
                order: order, vendor: line_items.first.vendor, line_items: line_items,
                rates: rates, categories: categories, deliveries: deliveries
              )
            )
          end
        end

        success(lines)
      end

      private

      def commission_vendor(order:, vendor:, line_items:, rates:, categories:, deliveries:)
        matched = line_items.filter_map do |line_item|
          rate = resolve(line_item: line_item, vendor: vendor, order: order, rates: rates, categories: categories)
          [line_item, rate] if rate
        end
        return [] if matched.empty?

        # Memoized per rate rather than per line. Where the seller's business
        # sits is the same question every time — so a basket governed by one
        # rate asks the tax service once — but a rate may carry its own
        # override, so two rates are still two answers.
        tax_rates = Hash.new do |cache, rate|
          cache[rate] = resolve_tax_rate(rate: rate, vendor: vendor, order: order)
        end

        lines = matched.map do |line_item, rate|
          write(rate: rate, vendor: vendor, order: order, line_item: line_item, tax_rate: tax_rates[rate])
        end

        # A fulfillment carries goods, not a rate, so the one that governs
        # delivery is whichever of the seller's matched rates asked for it.
        shipping_rate = matched.map(&:last).find(&:include_shipping?)
        return lines if shipping_rate.nil?

        deliveries.fetch(vendor.id, []).each do |fulfillment|
          next if fulfillment.taxable_basis.zero?

          lines << write(rate: shipping_rate, vendor: vendor, order: order,
                         fulfillment: fulfillment, tax_rate: tax_rates[shipping_rate])
        end

        lines
      end

      # The order's fulfillments, keyed by the seller whose goods they carry.
      #
      # Read off each fulfillment's own line items rather than assumed from the
      # order, because until the split lands an order still holds every
      # seller's goods — and a delivery carrying two sellers' items belongs to
      # neither of them alone. Charging both would bill one parcel twice, and
      # picking one would bill the wrong seller, so a shared delivery is
      # dropped here and stays uncommissioned until splitting gives each seller
      # their own. Once it does, every fulfillment is single-seller by
      # construction and this becomes the plain "the seller's deliveries".
      #
      # @return [Hash{Integer=>Array<Spree::Fulfillment>}]
      def deliveries_by_vendor(order)
        order.fulfillments.includes(fulfillment_items: :line_item).group_by do |fulfillment|
          sellers = fulfillment.fulfillment_items.map { |item| item.line_item&.vendor_id }.uniq

          sellers.one? ? sellers.first : nil
        end.except(nil)
      end

      def resolve(line_item:, vendor:, order:, rates:, categories:)
        Spree.commissions_resolve_rate_service.call(
          line_item: line_item, vendor: vendor, store: order.store, currency: order.currency,
          rates: rates, categories: categories
        ).value
      end

      def resolve_tax_rate(rate:, vendor:, order:)
        Spree.commissions_resolve_tax_rate_service.call(rate: rate, vendor: vendor, order: order).value
      end

      def write(rate:, vendor:, order:, tax_rate:, line_item: nil, fulfillment: nil)
        line = Spree.commissions_calculate_line_service.call(
          rate: rate, vendor: vendor, order: order,
          line_item: line_item, fulfillment: fulfillment, commission_tax_rate: tax_rate
        ).value
        line.save!
        line
      end
    end
  end
end
