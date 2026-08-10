module Spree
  module Api
    module V3
      module Admin
        module Companies
          # Anything nested under a company. The parent is resolved through the
          # store, so a company belonging to another tenant is a 404 rather than
          # a readable record.
          class BaseController < ResourceController
            scoped_resource :customers

            protected

            def set_parent
              @parent = current_store.companies.
                        accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:company_id])
              @company = @parent
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
