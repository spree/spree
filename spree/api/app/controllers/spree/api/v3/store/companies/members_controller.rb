module Spree
  module Api
    module V3
      module Store
        module Companies
          # The people with standing over one node, listed and added by its
          # members. Adding takes an email and always sends an invitation,
          # even to an existing customer: a member typing an address cannot
          # vouch that it is the person they mean, so the invitee accepts with
          # the emailed token. The response is the same whether or not the
          # email has an account. Any member can invite; restraint is
          # Enterprise's policy layer.
          class MembersController < BaseController
            # POST /api/v3/store/companies/:company_id/members
            def create
              result = Spree.company_add_member_service.call(
                company: @parent,
                email: params.require(:customer_email),
                inviter: current_user,
                require_acceptance: true
              )

              if result.success?
                render json: Spree.api.company_invitation_serializer.new(result.value, params: serializer_params).to_h,
                       status: :created
              else
                render_validation_error(result.value.errors)
              end
            end

            # DELETE /api/v3/store/companies/:company_id/members/:id
            def destroy
              @resource.destroy!
              head :no_content
            rescue ActiveRecord::RecordNotDestroyed => e
              render_validation_error(e.record.errors.presence || e.message)
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
