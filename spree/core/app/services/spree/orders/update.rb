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

        ApplicationRecord.transaction do
          ship_address_id_before = @order.ship_address_id
          assign_addresses(address_params)

          # Raised rather than returned: a `return` from inside the block commits
          # the transaction, leaving the address rows written above behind.
          raise ActiveRecord::RecordInvalid, @order unless @order.update(@params)

          process_items(items_param) if items_param

          if items_param || @order.ship_address_id != ship_address_id_before
            build_fulfillments
          end

          @order.recalculate_totals!
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

      def assign_addresses(address_params)
        address_params.each do |association, attributes|
          @order.public_send(:"#{association}_attributes=", attributes)
        end
      end

      def process_items(items)
        result = Spree::Orders::UpsertItems.call(order: @order, items: items)
        raise ActiveRecord::RecordInvalid, @order if result.failure?
      end

      def build_fulfillments
        result = Spree::Orders::BuildFulfillments.call(order: @order)
        raise ActiveRecord::RecordInvalid, @order if result.failure?
      end
    end
  end
end
