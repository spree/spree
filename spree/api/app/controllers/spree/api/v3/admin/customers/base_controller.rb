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

            def set_parent
              @parent = Spree.user_class.find_by_prefix_id!(params[:customer_id])
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
