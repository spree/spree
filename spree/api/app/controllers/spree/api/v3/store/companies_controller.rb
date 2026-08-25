module Spree
  module Api
    module V3
      module Store
        # A company node, self-served by its members. Authorization is
        # standing plus the storefront access policy — never CanCanCan, never
        # roles: OSS lets any member act within their subtree, and Enterprise
        # narrows through the policy class
        # (docs/plans/6.0-b2b-companies-and-catalogs.md).
        class CompaniesController < ResourceController
          prepend_before_action :require_authentication!

          # PATCH /api/v3/store/companies/:id
          def update
            authorize_storefront_write!(@resource)

            if @resource.update(permitted_params)
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::Company
          end

          def serializer_class
            Spree.api.company_serializer
          end

          # The nodes the caller has standing over — a node outside it is a
          # 404, never a readable record.
          def scope
            storefront_access_policy.scope(current_store.companies)
          end

          def permitted_params
            params.permit(:name)
          end
        end
      end
    end
  end
end
