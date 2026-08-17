module Spree
  module Api
    module V3
      module Seller
        # Anchor for seller-facing CRUD.
        #
        # Mirrors Seller::BaseController's concerns; any concern added to one
        # must be added to the other, since they anchor parallel inheritance
        # branches rather than one chain.
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::Seller::SellerContext
          include Spree::Api::V3::SellerAuthentication
          include Spree::Api::V3::ScopedAuthorization

          protected

          def authenticate_request!
            authenticate_seller!
          end

          # Every collection is rooted in the seller's own records.
          #
          # The inherited implementation roots at `for_store(current_store)`,
          # which on this branch would hand a seller the whole marketplace —
          # so subclasses name a `seller_association` and the root scope comes
          # from the seller itself. Tenancy is this fetch, not the ability:
          # authorizing without it reads store-wide.
          def scope
            return super if @parent.present?

            base_scope = current_seller.public_send(seller_association)
            base_scope = base_scope.includes(scope_includes) if scope_includes.any?
            base_scope = base_scope.preload_associations_lazily
            model_class.include?(Spree::TranslatableResource) ? base_scope.i18n : base_scope
          end

          # The seller association this controller reads through, defaulting to
          # the model's plural name (`Spree::Product` -> `products`). Override
          # when the association is named differently.
          #
          # @return [Symbol]
          def seller_association
            model_class.table_name.delete_prefix('spree_').to_sym
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action, resource)
          end

          def authorize_parent!(parent)
            authorize!(parent_ability_action, parent)
          end
        end
      end
    end
  end
end
