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

        ApplicationRecord.transaction do
          ship_address_id_before = @order.ship_address_id

          if @order.update(@params)
            process_items(items_param) if items_param
          else
            return failure(@order, @order.errors.full_messages.to_sentence)
          end

          if items_param || @order.ship_address_id != ship_address_id_before
            build_shipments
          end

          @order.update_with_updater!
        end

        success(@order.reload)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record, e.record.errors.full_messages.to_sentence)
      end

      private

      def process_items(items)
        result = Spree::Orders::UpsertItems.call(order: @order, items: items)
        raise ActiveRecord::RecordInvalid, @order if result.failure?
      end

      def build_shipments
        result = Spree::Orders::BuildShipments.call(order: @order)
        raise ActiveRecord::RecordInvalid, @order if result.failure?
      end
    end
  end
end
