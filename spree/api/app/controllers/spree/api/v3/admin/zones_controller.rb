module Spree
  module Api
    module V3
      module Admin
        class ZonesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::Zone
          end

          def serializer_class
            Spree.api.admin_zone_serializer
          end

          def permitted_params
            params.permit(:name, :description, :default_tax,
                         zone_members_attributes: [:id, :zoneable_type, :zoneable_id, :_destroy])
          end
        end
      end
    end
  end
end
