module Spree
  module Api
    module V3
      module Seller
        # Why an order was called off.
        #
        # Read-only here, like the other vocabularies, but gated by `orders`
        # rather than the `settings` key the operator's own CRUD sits behind —
        # `settings` is never seller-grantable, and a seller cancelling their
        # own order needs to name a reason from the marketplace's list.
        class OrderCancellationReasonsController < ReasonsController
          protected

          def model_class
            Spree::OrderCancellationReason
          end

          def reasons_association
            :order_cancellation_reasons
          end
        end
      end
    end
  end
end
