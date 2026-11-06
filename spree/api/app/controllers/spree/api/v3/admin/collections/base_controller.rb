module Spree
  module Api
    module V3
      module Admin
        module Collections
          # Anything nested under a collection. The parent resolves through the
          # store, so another store's collection is a 404.
          class BaseController < ResourceController
            scoped_resource :collections

            protected

            def set_parent
              @parent = current_store.collections.accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent)
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end
          end
        end
      end
    end
  end
end
