module Spree
  module Orders
    # Admin-side order update.
    #
    # Updates Order attributes plus optional line items via a flat `items: [...]`
    # array (matches POST shape and Store API convention). Standalone from
    # Spree::Carts::Update (storefront).
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params: {})
        @order = order
        @params = params.to_h.deep_symbolize_keys

        items_param = @params.delete(:items)
        address_params = extract_address_params
        scope_store_references

        # requires_new: the rescue below sits outside the block, so joining a
        # caller's open transaction (the API's order lock) would let it commit
        # the half-applied edit.
        ApplicationRecord.transaction(requires_new: true) do
          ship_address_id_before = @order.ship_address_id
          assign_addresses(address_params)

          # Raised rather than returned: a `return` from inside the block commits
          # the transaction, leaving the address rows written above behind.
          raise ActiveRecord::RecordInvalid, @order unless @order.update(@params)

          # An address row edited in place keeps its id, so an edit to the fields a quote reads counts too.
          # Read before releasing the previous customer's balance: the removal
          # services reload the order, which drops the address's saved changes.
          destination_changed = @order.ship_address_id != ship_address_id_before || @order.ship_address&.saved_change_to_destination?

          release_previous_customer_balance if @order.saved_change_to_customer_id? && !@order.completed?
          process_items(items_param) if items_param

          build_fulfillments(keep_selection: !destination_changed) if items_param || destination_changed

          @order.recalculate_totals!
          @order.update_statuses!
        end

        success(@order.reload)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record, e.record.errors.full_messages.to_sentence)
      end

      private

      # The spellings each address accepts, in the order they win. The public
      # name is the documented one; the others are what older callers send.
      ADDRESS_PARAM_ALIASES = {
        ship_address: %i[shipping_address ship_address ship_address_attributes],
        bill_address: %i[billing_address bill_address bill_address_attributes]
      }.freeze

      # Addresses are pulled out of the attribute payload and applied through
      # the deduplicating writers, the way Orders::Create does. Handing a hash
      # to `update` would reach the belongs_to writer and raise instead.
      #
      # Every spelling is removed even when unused: one left behind is either
      # a hash for `update` to choke on, or an `_attributes` key that quietly
      # overwrites the address assigned here.
      def extract_address_params
        ADDRESS_PARAM_ALIASES.transform_values do |aliases|
          aliases.map { |key| @params.delete(key) }.compact.find(&:present?)
        end.compact_blank
      end

      # Named by id in the payload and read through the order's own store, as
      # Orders::Create does: the model only checks that the record exists, so
      # another store's market, channel or warehouse would otherwise be
      # accepted.
      STORE_REFERENCES = {
        market_id: :markets,
        channel_id: :channels,
        preferred_stock_location_id: :stock_locations
      }.freeze

      def scope_store_references
        STORE_REFERENCES.each do |key, association|
          next if @params[key].blank?

          @params[key] = @order.store.public_send(association).find_by_param!(@params[key]).id
        end
      end

      def assign_addresses(address_params)
        address_params.each do |association, attributes|
          @order.public_send(:"#{association}_attributes=", attributes)
        end
      end

      def process_items(items)
        result = Spree::Orders::UpsertItems.call(order: @order, items: items)
        propagate_step_failure!(result, fallback: 'Failed to update items on order') if result.failure?
      end

      # Store credit and a named gift card pay only for their owner's orders,
      # so a draft that changes hands gives back what the previous customer
      # put on it. A gift card without a named owner is spendable by anyone
      # holding its code, so it stays.
      def release_previous_customer_balance
        gift_card = @order.gift_card

        if gift_card.nil?
          # Nothing to give back: skip the service, which reloads the order.
          return unless @order.payments.store_credits.valid.exists?

          result = Spree.store_credit_remove_service.call(order: @order)
          propagate_step_failure!(result, fallback: I18n.t('spree.store_credit_paid_by_previous_customer')) if result.failure?
        elsif gift_card.customer_id.present? && gift_card.customer_id != @order.customer_id
          # The remove workflow voids only checkout payments and would detach
          # the card from one already captured, so refuse as store credit does.
          if @order.payments.store_credits.valid.where.not(status: 'checkout').exists?
            @order.errors.add(:base, I18n.t('spree.gift_card_paid_by_previous_customer'))
            raise ActiveRecord::RecordInvalid, @order
          end

          result = Spree.gift_card_remove_workflow.call(order: @order)
          propagate_step_failure!(result, fallback: 'Failed to remove gift card from order') if result.failure?
        end
      end

      def build_fulfillments(keep_selection:)
        result = Spree::Orders::BuildFulfillments.call(order: @order, keep_selection: keep_selection)
        propagate_step_failure!(result, fallback: 'Failed to build shipments') if result.failure?
      end

      # Surface why the step failed on the order, the way Orders::Create does.
      # Raising RecordInvalid with the order's own untouched errors renders a
      # 422 with an empty message, because a rejected batch carries its reason
      # on the Result rather than on the order.
      def propagate_step_failure!(result, fallback:)
        record = result.value
        if record.respond_to?(:errors) && record.errors.any? && record != @order
          record.errors.full_messages.each { |message| @order.errors.add(:base, message) }
        elsif result.error.to_s.present?
          @order.errors.add(:base, result.error.to_s)
        elsif @order.errors.empty?
          @order.errors.add(:base, fallback)
        end

        raise ActiveRecord::RecordInvalid, @order
      end
    end
  end
end
