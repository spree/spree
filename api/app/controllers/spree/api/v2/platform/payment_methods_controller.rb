module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodsController < ResourceController
          private

          def model_class
            Spree::PaymentMethod
          end
        end
      end
    end
  end
end
