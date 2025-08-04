module Spree
  module Api
    module V2
      module Platform
        class PaymentsController < ResourceController
          include NumberResource

          private

          def model_class
            Spree::Payment
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_payment_serializer.constantize
          end
        end
      end
    end
  end
end
