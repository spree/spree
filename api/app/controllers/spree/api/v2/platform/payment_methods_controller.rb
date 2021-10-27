module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodsController < ResourceController
          private

          def model_class
            Spree::PaymentMethod
          end

          def spree_permitted_attributes
            Spree::PaymentMethod.json_api_permitted_attributes + [store_ids: []]
          end
        end
      end
    end
  end
end
