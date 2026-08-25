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

            # POST /api/v3/admin/companies/:company_id/memberships
            def create
              result = Spree.company_add_member_service.call(
                company: @parent,
                email: params.require(:customer_email),
                role: params[:role],
                metadata: params[:metadata].respond_to?(:permit) ? params[:metadata].permit!.to_h : params[:metadata]
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

            def model_class
              Spree::CompanyMembership
            end

            def serializer_class
              Spree.api.admin_company_membership_serializer
            end

            def scope
              @parent.memberships
            end

            def parent_association
              :memberships
            end

            def collection_includes
              [:customer]
            end

            def permitted_params
              params.permit(:customer_email, :role, metadata: {})
            end
          end
        end
      end
    end
  end
end
