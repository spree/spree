module Spree
  module Api
    module V3
      module Admin
        module Companies
          # The people with standing over one node. Creation takes an email
          # and does the right thing: a membership for an existing customer,
          # an invitation otherwise — the same convergent behavior as the
          # storefront endpoint.
          class MembershipsController < BaseController
            # Overriding `scope` bypasses the base class's `accessible_by`, so
            # without this a role with no customer permission could still list
            # who buys for a node — and memberships carry customer emails.
            before_action :authorize_parent_access!

            request_params :company_membership do |body|
              body.attribute :customer_id, :string,
                             example: 'cus_UkLWZg9DAJ',
                             description: 'An existing customer, who becomes a member immediately. ' \
                                          'Send this or `customer_email`.'
              body.attribute :customer_email, :string,
                             example: 'buyer@example.com',
                             description: 'An existing customer becomes a member immediately; an unknown ' \
                                          'email becomes an invitation, and the response is an invitation ' \
                                          'instead of a membership. Send this or `customer_id`.'
              body.attribute :metadata, :hash
            end

            # POST /api/v3/admin/companies/:company_id/memberships
            def create
              customer = member_customer
              result = Spree.company_add_member_service.call(
                company: @parent,
                customer: customer,
                email: customer ? nil : params.require(:customer_email),
                metadata: permitted_params[:metadata]
              )

              if result.success?
                serializer = if result.value.is_a?(Spree::CompanyInvitation)
                               Spree.api.admin_company_invitation_serializer
                             else
                               serializer_class
                             end
                render json: serializer.new(result.value, params: serializer_params).to_h, status: :created
              else
                render_validation_error(result.value.errors)
              end
            end

            protected

            # Through the ability, like every customer lookup here: a customer
            # this role cannot see 404s rather than joining the company.
            def member_customer
              return if params[:customer_id].blank?

              Spree.customer_class.
                accessible_by(current_ability, :show).
                find_by_prefix_id!(params[:customer_id])
            end

            def model_class
              Spree::CompanyMembership
            end

            def serializer_class
              Spree.api.admin_company_membership_serializer
            end

            def scope
              @parent.memberships
            end

            def collection_includes
              [:customer]
            end

            def permitted_params
              params.permit(*declared_permitted_attributes)
            end
          end
        end
      end
    end
  end
end
