module Spree
  module Api
    module V3
      module Store
        module Companies
          # The people with standing over one node, listed and added by its
          # members. Adding takes an email and does the right thing: a
          # membership for an existing customer, an invitation otherwise —
          # the same convergent behavior as the dashboard endpoint. Any member
          # can invite; restraint is Enterprise's policy layer.
          class MembersController < BaseController
            # POST /api/v3/store/companies/:company_id/members
            def create
              result = Spree.company_add_member_service.call(
                company: @parent,
                email: params.require(:customer_email),
                inviter: current_user
              )

              if result.success?
                serializer = if result.value.is_a?(Spree::CompanyInvitation)
                               Spree.api.company_invitation_serializer
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
              Spree.api.company_membership_serializer
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
          end
        end
      end
    end
  end
end
