module Spree
  module Api
    module V3
      module Store
        # Why goods come back — offered when opening a return or an exchange.
        class ReturnReasonsController < ReasonsController
          protected

          def model_class
            Spree::ReturnReason
          end

          def serializer_class
            Spree.api.return_reason_serializer
          end
        end
      end
    end
  end
end
