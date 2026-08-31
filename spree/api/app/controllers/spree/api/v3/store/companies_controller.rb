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
          rate_limit to: Spree::Api::Config[:rate_limit_register], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_register]) }

          # POST /api/v3/store/companies
          # The B2B front door: an authenticated customer — an existing
          # retail customer included — founds a root company plus their own
          # membership in one call, rate-limited like customer registration
          # (docs/plans/6.0-b2b-company-self-registration.md).
          def create
            result = Spree.company_register_workflow.call(
              store: current_store,
              customer: current_user,
              name: create_params[:name],
              registration: create_params[:registration]&.to_h
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_result_error(result)
            end
          end

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

          # `registration` is the free-form answers block the merchant's
          # registration form collects — arbitrary keys by design, stored
          # under the company's `metadata['registration']`.
          def create_params
            params.permit(:name, registration: {})
          end
        end
      end
    end
  end
end
