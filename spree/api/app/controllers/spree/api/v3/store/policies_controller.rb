module Spree
  module Api
    module V3
      module Store
        class PoliciesController < Store::ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::Policy
          end

          def serializer_class
            Spree.api.policy_serializer
          end

          # Accept slug (e.g., return-policy) or prefixed ID (e.g., pol_abc123)
          def find_resource
            if params[:id].to_s.start_with?('pol_')
              scope.find_by_prefix_id!(params[:id])
            else
              scope.friendly.find(params[:id])
            end
          end

          def scope
            super.order(:name)
          end
        end
      end
    end
  end
end
