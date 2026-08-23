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

          if @order.update(@params)
            process_items(items_param) if items_param
          else
            return failure(@order, @order.errors.full_messages.to_sentence)
          end

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

      # Addresses are pulled out of the attribute payload and applied through
      # the deduplicating writers, the way Orders::Create does. Handing a hash
      # to `update` would reach the belongs_to writer and raise instead.
      # Both the public names and the column names are accepted.
      def extract_address_params
        {
          ship_address: @params.delete(:shipping_address) || @params.delete(:ship_address),
          bill_address: @params.delete(:billing_address) || @params.delete(:bill_address)
        }.compact_blank
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
