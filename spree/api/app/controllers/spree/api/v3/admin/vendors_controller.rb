module Spree
  module Api
    module V3
      module Admin
        # Sellers, as the marketplace operator manages them.
        #
        # Every status change is its own member action rather than mass
        # assignment, because each one is a workflow with its own arguments —
        # suspending carries a reason, inviting carries an email address. The
        # `status` field is deliberately not writable through `update`: a
        # vendor moved by a PATCH would skip the mail, the payout provisioning
        # and the extension hooks that make the transition mean something.
        class VendorsController < ResourceController
          # Sellers are their own catalog resource: `read_vendors`/`write_vendors`
          # is what a key needs here, and neither is grantable to a seller's own
          # panel — managing sellers is the operator's job.
          scoped_resource :vendors

          before_action :set_resource, only: [:show, :update, :destroy, :invite, :approve, :suspend, :reject]

          # POST /api/v3/admin/vendors/:id/invite
          #
          # Opens the vendor's team to someone. They become a member when they
          # accept, on the same invitation rail the store's own staff use.
          def invite
            result = Spree.vendor_invite_workflow.call(
              vendor: @resource,
              email: params[:email],
              role: role_for_invite,
              inviter: try_spree_current_user
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_result_error(result)
            end
          end

          # PATCH /api/v3/admin/vendors/:id/approve
          def approve
            run_workflow(Spree.vendor_approve_workflow, approver: try_spree_current_user)
          end

          # PATCH /api/v3/admin/vendors/:id/suspend
          def suspend
            run_workflow(Spree.vendor_suspend_workflow,
                         reason: params[:reason],
                         suspended_by: try_spree_current_user)
          end

          # PATCH /api/v3/admin/vendors/:id/reject
          def reject
            run_workflow(Spree.vendor_reject_workflow,
                         reason: params[:reason],
                         rejected_by: try_spree_current_user)
          end

          protected

          def model_class
            Spree::Vendor
          end

          def serializer_class
            Spree.api.admin_vendor_serializer
          end

          # `users` is preloaded because a vendor team is small and its count is
          # a cheap `.size` over loaded rows. `products` deliberately is not: a
          # catalog can run to thousands, so the serializer counts it in SQL
          # rather than materializing it just to measure it.
          def collection_includes
            [:billing_address, :returns_address, :users]
          end

          # Enumerated rather than borrowing the legacy global list, which
          # permits :id, :user_id and :deleted_at — the first of which would
          # reintroduce the address-by-id hole below.
          ADDRESS_KEYS = [
            :first_name, :last_name, :company, :address1, :address2, :city,
            :postal_code, :zipcode, :phone, :country_code, :state_code, :state_name, :label
          ].freeze

          # The vendor's own profile fields, plus the settlement and tax
          # configuration only the operator sets. `status` is absent by
          # design — see the class comment.
          #
          # Addresses are written as nested attributes, never as ids: an
          # address has no store of its own, so accepting `billing_address_id`
          # would bind an arbitrary row and the serializer would render it
          # back in full — an enumeration oracle over every customer address
          # on the installation.
          def permitted_params
            normalize_params(
              params.permit(:name, :slug, :contact_email, :billing_email, :about,
                            :logo, :square_logo, :cover_photo,
                            :tax_remittance, :payouts_schedule_interval, :minimum_payout_amount,
                            :holiday_mode_until,
                            metadata: {},
                            billing_address: ADDRESS_KEYS,
                            returns_address: ADDRESS_KEYS,
                            custom_fields: [:id, :custom_field_definition_id, :value, { value: [] }, { value: {} }])
            )
          end

          private

          def run_workflow(workflow, **arguments)
            result = workflow.call(vendor: @resource, **arguments)

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end

          # Read through the vendor's own roles: a role id naming somewhere
          # else is a 404 here rather than an invitation into another team.
          def role_for_invite
            return nil if params[:role_id].blank?

            @resource.roles.find_by_prefix_id!(params[:role_id])
          end
        end
      end
    end
  end
end
