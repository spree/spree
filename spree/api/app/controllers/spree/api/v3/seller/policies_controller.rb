module Spree
  module Api
    module V3
      module Seller
        # A seller's own legal documents — their returns policy, shipping
        # policy, whatever the marketplace asks them to publish.
        #
        # Rooted in `current_seller.policies`, so the operator's store policies
        # and every other seller's are invisible here: an id belonging to
        # either is a 404, not a permission error.
        class PoliciesController < Seller::ResourceController
          scoped_resource :seller_profile

          protected

          def model_class
            Spree::Policy
          end

          def serializer_class
            Spree.api.seller_policy_serializer
          end

          def resource_permitted_attributes
            [:name, :slug, :body]
          end

          # Accept slug or prefixed ID, matching the storefront's lookup.
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

          # Authorize the seller's own profile surface, not `Spree::Policy`.
          #
          # The catalog gives that class to `settings` — the operator's key,
          # which a seller must never hold — so the inherited record check
          # would ask for a grant no seller has and deny every request. The
          # question this endpoint actually asks is "may this seller edit
          # their own record", which is what `:seller_profile` answers; which
          # policy they may touch is settled by the scope above, never by the
          # ability.
          def authorize_resource!(_resource = @resource, action = action_name.to_sym)
            authorize!(action, :seller_profile)
          end
        end
      end
    end
  end
end
