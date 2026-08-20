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
        # seller moved by a PATCH would skip the mail, the payout provisioning
        # and the extension hooks that make the transition mean something.
        class SellersController < ResourceController
          # Sellers are their own catalog resource: `read_sellers`/`write_sellers`
          # is what a key needs here, and neither is grantable to a seller's own
          # panel — managing sellers is the operator's job.
          scoped_resource :sellers

          before_action :set_resource, only: [:show, :update, :destroy, :invite, :approve, :suspend, :reject,
                                              :onboarding, :reopen_onboarding]

          # POST /api/v3/admin/sellers/:id/invite
          #
          # Opens the seller's team to someone. They become a member when they
          # accept, on the same invitation rail the store's own staff use.
          def invite
            result = Spree.seller_invite_workflow.call(
              seller: @resource,
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

          # GET /api/v3/admin/sellers/:id/onboarding
          #
          # Where this seller stands against the marketplace's checklist. Its
          # own action rather than a field on the seller: evaluating it costs
          # a handful of queries per seller, which a list of twenty-five must
          # not pay for a column most operators are not looking at.
          def onboarding
            authorize_resource!(@resource, :show)

            requirements = Spree::Sellers::Requirements.new(@resource)

            render json: {
              status: @resource.status,
              progress: requirements.progress,
              requirements: serialize_requirement_statuses(requirements.statuses)
            }
          end

          # PATCH /api/v3/admin/sellers/:id/approve
          #
          # `override_requirements` admits a seller whose checklist is not
          # finished — the operator's deliberate exception, which the event
          # records alongside what was outstanding.
          def approve
            run_workflow(Spree.seller_approve_workflow,
                         approver: try_spree_current_user,
                         override_requirements: ActiveModel::Type::Boolean.new.cast(params[:override_requirements]))
          end

          # PATCH /api/v3/admin/sellers/:id/reopen_onboarding
          #
          # Sends a seller awaiting review back to onboarding with a note.
          # Distinct from reject, which turns them away.
          def reopen_onboarding
            run_workflow(Spree.seller_reopen_onboarding_workflow,
                         note: params[:note],
                         reopened_by: try_spree_current_user)
          end

          # PATCH /api/v3/admin/sellers/:id/suspend
          def suspend
            run_workflow(Spree.seller_suspend_workflow,
                         reason: params[:reason],
                         suspended_by: try_spree_current_user)
          end

          # PATCH /api/v3/admin/sellers/:id/reject
          def reject
            run_workflow(Spree.seller_reject_workflow,
                         reason: params[:reason],
                         rejected_by: try_spree_current_user)
          end

          protected

          def model_class
            Spree::Seller
          end

          def serializer_class
            Spree.api.admin_seller_serializer
          end

          # `users` is preloaded because a seller team is small and its count is
          # a cheap `.size` over loaded rows. `products` deliberately is not: a
          # catalog can run to thousands, so the serializer counts it in SQL
          # rather than materializing it just to measure it.
          def collection_includes
            [:users]
          end

          # What the serializer's onboarding progress reads for every seller,
          # on the list and on the profile alike: the checklist's kinds look
          # at addresses, branding and the seller's own submissions, and the
          # requirements themselves hang off the store — one row shared by
          # every seller on the page, so it loads once. Applied to the scope
          # rather than the collection so a single-seller read gets it too.
          def scope_includes
            [:billing_address, :returns_address, :requirement_submissions,
             { store: :seller_requirements, logo_attachment: :blob, cover_photo_attachment: :blob }]
          end

          # Enumerated rather than borrowing the legacy global list, which
          # permits :id, :user_id and :deleted_at — the first of which would
          # reintroduce the address-by-id hole below.
          ADDRESS_KEYS = [
            :first_name, :last_name, :company, :address1, :address2, :city,
            :postal_code, :zipcode, :phone, :country_code, :state_code, :state_name, :label
          ].freeze

          # The seller's own profile fields, plus the settlement and tax
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

          # `onboarding` is a read of the seller — it changes nothing.
          def read_actions
            super + %w[onboarding]
          end

          private

          def serialize_requirement_statuses(statuses)
            serializer = Spree.api.admin_seller_requirement_status_serializer

            statuses.map { |status| serializer.new(status, params: serializer_params).to_h }
          end

          def run_workflow(workflow, **arguments)
            result = workflow.call(seller: @resource, **arguments)

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end

          # Read through the seller's own roles: a role id naming somewhere
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
