module Spree
  module Api
    module V3
      module Admin
        module Customers
          # Shared base for resources nested under a customer
          # (`/admin/customers/:customer_id/...`). Resolves the parent customer
          # and authorizes it per action (`:show` for reads, `:update` for
          # writes) so a role that can only view a customer can't mutate its
          # nested collections. Mirrors `Orders::BaseController`.
          class BaseController < ResourceController
            scoped_resource :customers

            protected

            # Resolve the customer through the ability-scoped relation, using
            # the action-appropriate ability on the parent (`:show` for reads,
            # `:update` for writes — see `parent_ability_action`). A customer
            # the caller can't access for the requested action is filtered out
            # and 404s, rather than leaking its existence as a 403. Users are
            # global in Spree (`User.for_store` is a no-op), so the ability is
            # the only boundary here.
            def set_parent
              @parent = Spree.user_class.
                        accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:customer_id])
            end
          end
        end
      end
    end
  end
end
