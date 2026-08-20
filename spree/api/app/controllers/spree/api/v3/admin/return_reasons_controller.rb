module Spree
  module Api
    module V3
      module Admin
        class ReturnReasonsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::ReturnReason
          end

          def serializer_class
            Spree.api.admin_return_reason_serializer
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :name, :active)
          end
        end
      end
    end
  end
end
