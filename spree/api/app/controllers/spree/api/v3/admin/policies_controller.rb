module Spree
  module Api
    module V3
      module Admin
        # The store's own legal documents. A seller's policies belong to the
        # seller and are managed on the seller branch — this controller never
        # reaches them, since its scope is the store's own association.
        class PoliciesController < ResourceController
          scoped_resource :settings

          request_params :policy do
            string :name, required: :create, example: 'Wholesale Policy'
            string :slug, example: 'wholesale-policy'
            string :body, nullable: true, example: '<p>Trade orders ship within five working days.</p>'
          end

          protected

          def model_class
            Spree::Policy
          end

          def serializer_class
            Spree.api.admin_policy_serializer
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
