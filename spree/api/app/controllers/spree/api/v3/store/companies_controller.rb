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

          request_params 'RegisterCompanyParams', action: :create do |body|
            body.attribute :name, :string, required: true, example: 'Nowak Tools sp. z o.o.'
            body.attribute :registration, :hash,
              description: "Free-form answers from the merchant's registration form, stored on the company."
          end

          request_params 'UpdateCompanyParams', action: :update do |body|
            body.attribute :name, :string, example: 'Acme Industrial Group'
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

          # POST founds a root company plus the caller's membership — the
          # B2B front door, open to an existing retail customer and
          # rate-limited like customer registration
          # (docs/plans/6.1-b2b-company-self-registration.md).
          def create_workflow
            Spree.company_register_workflow
          end

          def create_workflow_arguments
            {
              store: current_store,
              customer: current_user,
              name: params[:name],
              registration: params[:registration]&.to_unsafe_h
            }
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
            params.permit(*declared_permitted_attributes)
          end
        end
      end
    end
  end
end
