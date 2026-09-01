module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # Anything nested under a catalog. The parent resolves through the
          # store, so a catalog belonging to another tenant is a 404 rather
          # than a readable record.
          class BaseController < ResourceController
            scoped_resource :products

            protected

            def set_parent
              @parent = current_store.catalogs.
                        accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:catalog_id])
              @catalog = @parent
            end

            def authorize_parent_access!
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
