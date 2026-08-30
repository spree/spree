module Spree
  module Orders
    # Draft-order line item update: quantity, metadata and the negotiated
    # unit price in one place. Recalculates the order only when money moved —
    # metadata-only edits carry no money impact. Unlike the cart side
    # (Carts::SetQuantity), drafts hold no checkout stock reservations, so
    # there is nothing to re-reserve here.
    #
    # +price+ is tri-state: not passed leaves pricing alone, an amount
    # negotiates the line (stamping +price_source: 'manual'+ so nothing
    # re-prices it), an explicit nil reverts a negotiated line to catalog
    # pricing through the resolver. Overrides are pre-placement only — a
    # placed order's money edits stay fees and discounts.
    class UpdateItem
      prepend Spree::ServiceModule::Base

      # Distinguishes "price not passed" from the explicit +price: nil+ revert.
      PRICE_NOT_PROVIDED = Object.new.freeze

      def call(order:, line_item:, quantity: nil, metadata: nil, price: PRICE_NOT_PROVIDED)
        price_provided = !price.equal?(PRICE_NOT_PROVIDED)

        if price_provided && order.completed?
          return reject_price(line_item, Spree.t('cart_line_item.price_override_not_allowed'))
        end

        attributes = {}
        attributes[:quantity] = quantity unless quantity.nil?
        attributes[:metadata] = metadata unless metadata.nil?

        if price_provided && !price.nil?
          manual_price = parse_manual_price(price)
          return reject_price(line_item, Spree.t('cart_line_item.invalid_price')) if manual_price.nil?

          attributes[:price] = manual_price
          attributes[:price_source] = Spree::LineItem::MANUAL_PRICE_SOURCE
          attributes[:price_list_id] = nil
        end

        quantity_changing = attributes.key?(:quantity) && attributes[:quantity].to_i != line_item.quantity
        reverting = price_provided && price.nil?

        # The revert consults the pricing provider — a network call for an
        # external-pricing store — so it runs before the transaction opens.
        revert_manual_price(order, line_item, attributes) if reverting

        ActiveRecord::Base.transaction do
          return failure(line_item) unless line_item.update(attributes)

          Spree::Orders::Recalculate.call(order: order, line_item: line_item) if quantity_changing || price_provided
        end

        success(line_item)
      end

      private

      # Puts the reason on the record before failing. +failure(record, message)+
      # would drop it: the base helper replaces the message with the record's
      # own (empty) errors whenever it responds to +errors+, leaving the API
      # to render a 422 with nothing in it.
      # Added to :base rather than :price so the full message reads as written
      # — Rails prefixes the humanized attribute onto a field error, which
      # would render "Price Price must be a non-negative number".
      def reject_price(line_item, message)
        line_item.errors.add(:base, message)
        failure(line_item)
      end

      # Strict parse — a non-numeric value is refused, never coerced to zero.
      # finite? is not redundant with negative?: BigDecimal parses "NaN" and
      # "Infinity", and neither is negative, so both would reach the insert
      # and fail as a 500 rather than a validation message.
      # @return [BigDecimal, nil]
      def parse_manual_price(value)
        parsed = BigDecimal(value.to_s)
        return if parsed.negative? || !parsed.finite?

        parsed
      rescue ArgumentError
        nil
      end

      # Clears the manual marker in memory, then re-prices through the
      # resolver at the quantity this update lands on. A resolver with no
      # answer (no catalog price in this currency) leaves the amount as it
      # stands — only the marker is guaranteed to clear.
      def revert_manual_price(order, line_item, attributes)
        line_item.assign_attributes(
          attributes.merge(price_source: nil, price_list_id: nil)
        )

        result = Spree::Carts::PriceItems.new.call(cart: order, line_items: [line_item])
        Spree::Carts::PriceItems.apply(result.value, persist: false) if result.success?

        # The in-memory assignments (including any resolved price) ride the
        # transactional update below.
        attributes.merge!(
          price: line_item.price,
          price_source: line_item.price_source,
          price_list_id: line_item.price_list_id
        )
      end
    end
  end
end
