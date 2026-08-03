module Spree
  module Api
    module V3
      module Admin
        # Cross-order listing of exchanges — "what is awaiting fulfillment
        # across the whole store". Read-only by route: opening an exchange
        # needs an order, so creation and the status transitions stay on the
        # nested Orders::ExchangesController.
        class ExchangesController < ResourceController
          # Post-sale records are order data: a key that may read orders may
          # read these, and nothing here writes.
          scoped_resource :orders

          protected

          def model_class
            Spree::Exchange
          end

          def serializer_class
            Spree.api.admin_exchange_serializer
          end

          def collection_includes
            [:order, :reason, :stock_location, { exchange_line_items: [:original_variant, :new_variant] }]
          end
        end
      end
    end
  end
end
