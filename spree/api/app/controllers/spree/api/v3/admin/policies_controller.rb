module Spree
  module Api
    module V3
      module Admin
        # The store's own legal documents. A seller's policies belong to the
        # seller and are managed on the seller branch — this controller never
        # reaches them, since its scope is the store's own association.
        class PoliciesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::Policy
          end

          def serializer_class
            Spree.api.admin_policy_serializer
          end

          def resource_permitted_attributes
            [:name, :slug, :body]
          end

          # Accept slug (e.g. returns-policy) or prefixed ID (e.g. pol_abc123),
          # matching the storefront's lookup.
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
