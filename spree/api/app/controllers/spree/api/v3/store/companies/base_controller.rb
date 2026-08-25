module Spree
  module Api
    module V3
      module Store
        module Companies
          # Anything a member manages under a company node. The parent is
          # resolved through the caller's standing, so a node they may not act
          # for is a 404 rather than a readable record.
          class BaseController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = @company = storefront_access_policy.
                        scope(current_store.companies).
                        find_by_prefix_id!(params[:company_id])
            end
          end
        end
      end
    end
  end
end
