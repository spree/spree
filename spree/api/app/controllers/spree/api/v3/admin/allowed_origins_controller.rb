module Spree
  module Api
    module V3
      module Admin
        class AllowedOriginsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::AllowedOrigin
          end

          def serializer_class
            Spree.api.admin_allowed_origin_serializer
          end

          def permitted_params
            params.permit(:origin)
          end
        end
      end
    end
  end
end
