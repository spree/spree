module Spree
  module Carts
    # Resolves what each line item should cost, through the store's pricing
    # provider.
    #
    # Split deliberately into two calls. {#call} only *asks* — it may reach an
    # external system, so it runs outside any transaction, as an
    # +external_step+. {.apply} then writes what was resolved, inside the
    # caller's transaction. Holding a database transaction open across a
    # network call is what turns a slow ERP into a table full of stuck locks.
    #
    # A line item on a completed order is never re-priced: the price it was
    # sold at is a fact about that sale, not a question to ask again.
    class PriceItems
      prepend ::Spree::ServiceModule::Base

      # @param cart [Spree::Cart, Spree::Order]
      # @param line_items [Enumerable<Spree::LineItem>, nil] defaults to all of them
      # @return [Spree::ServiceModule::Result] value is an array of
      #   +[line_item, price, price_source]+ triples for {.apply}
      def call(cart:, line_items: nil)
        return success([]) if cart.blank?

        items = Array(line_items.presence || cart.line_items)
        # A placed order's existing lines are frozen — what they sold at is a
        # fact. A line being added to it now still needs a price, or an admin
        # amendment bills list price to a contract customer.
        items = items.reject(&:persisted?) if money_frozen?(cart)
        return success([]) if items.empty?

        # The source comes from the answer, not the store's setting: a
        # provider that declined the context, or fell back, priced from the
        # catalog and the line must say so.
        resolutions = items.filter_map do |line_item|
          price = resolve_price(line_item, cart)
          next if price.blank?

          [line_item, price, price.price_source]
        end

        success(resolutions)
      rescue Spree::Pricing::PriceResolution::ProviderUnavailable => e
        # Strict policy: the store would rather sell nothing than sell at a
        # price it cannot stand behind.
        failure(cart, e.message)
      end

      # Writes resolved prices. Safe inside a transaction — no provider is
      # consulted here.
      #
      # @param resolutions [Array<Array>] triples from {#call}
      # @param persist [Boolean] false assigns without saving, for callers
      #   that save the record themselves
      # @return [void]
      def self.apply(resolutions, persist: true)
        Array(resolutions).each do |line_item, price, source|
          owner = line_item.owner
          amount = price.price_including_vat_for(
            address: owner&.tax_address, country: owner&.tax_country, market: owner&.market
          )
          # Marked before the blank guard: the provider has already answered,
          # so a restatement that comes back blank must still not send the
          # after_save callback back to the provider from inside the caller's
          # transaction. Only the assign-for-a-coming-save case needs it — a
          # persisted write goes through update_columns and fires no callbacks.
          line_item.price_resolved = true unless persist
          next if amount.blank?

          line_item.assign_attributes(price: amount, price_list_id: price.price_list_id, price_source: source)
          next unless persist && line_item.persisted? && line_item.changed?

          line_item.update_columns(line_item.changes.transform_values(&:last).merge(updated_at: Time.current))
        end
      end

      private

      # The same rule Carts::RecalculateTotals uses: once an order is placed
      # its money stops being a question. Re-pricing here would rewrite what a
      # customer was actually charged.
      def money_frozen?(cart)
        cart.is_a?(Spree::Order) && cart.completed?
      end

      def resolve_price(line_item, cart)
        context = Spree::Pricing::Context.from_order(line_item.variant, cart, quantity: line_item.quantity)
        line_item.variant.price_for(context)
      end
    end
  end
end
