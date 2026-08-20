module Spree
  module Api
    module V3
      module Admin
        # The operator's review queue: what sellers have submitted about the
        # marketplace's requirements, and the decisions on them.
        #
        # Each decision is its own member action because each is a workflow
        # carrying its own arguments — a rejection carries the reason the
        # seller needs in order to fix it — and because a status moved by
        # PATCH would skip the mail and the extension hooks.
        class SellerRequirementSubmissionsController < ResourceController
          scoped_resource :sellers

          before_action :set_resource, only: [:show, :accept, :reject, :download]

          # POST /api/v3/admin/sellers/:seller_id/requirement_submissions
          #
          # The operator excusing one seller from something the marketplace
          # asks of everyone. Creating anything else here would be the
          # operator submitting on the seller's behalf, which is what the
          # seller's own branch is for.
          def create
            authorize! :create, Spree::SellerRequirementSubmission

            result = Spree.seller_requirement_submission_waive_workflow.call(
              seller: seller,
              requirement: requirement_from_params,
              reviewed_by: try_spree_current_user,
              review_note: params[:review_note]
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_result_error(result)
            end
          end

          # PATCH /api/v3/admin/sellers/:seller_id/requirement_submissions/:id/accept
          def accept
            run_workflow(Spree.seller_requirement_submission_accept_workflow)
          end

          # PATCH /api/v3/admin/sellers/:seller_id/requirement_submissions/:id/reject
          def reject
            run_workflow(Spree.seller_requirement_submission_reject_workflow)
          end

          # GET /api/v3/admin/sellers/:seller_id/requirement_submissions/:id/download
          #
          # Served through the API rather than as a storage link: these are
          # business registrations and identity documents, so each read is
          # authorized instead of being open to anyone holding a URL.
          def download
            unless @resource.file.attached?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Submission has no attached file',
                status: :unprocessable_content
              )
            end

            send_data(
              @resource.file.download,
              filename: @resource.file.filename.to_s,
              type: @resource.file.content_type,
              disposition: 'attachment'
            )
          end

          protected

          def model_class
            Spree::SellerRequirementSubmission
          end

          def serializer_class
            Spree.api.admin_seller_requirement_submission_serializer
          end

          # The parent is set and authorized by the base controller, and the
          # scope hangs off it — so a submission belonging to another
          # marketplace is a 404 rather than a document.
          def parent_association
            :requirement_submissions
          end

          # The serializer reads each row's file and its seller, so both are
          # loaded with the page rather than per row.
          def collection_includes
            [:requirement, :reviewed_by, :seller, { file_attachment: :blob }]
          end

          def read_actions
            super + %w[download]
          end

          # Scope-fetched through the store, then filtered by what this role may
          # do with it: reading a seller is not licence to decide its
          # submissions, which `authorize_parent!` enforces per action.
          def set_parent
            @parent = current_store.sellers.
                      accessible_by(current_ability, parent_ability_action).
                      find_by_prefix_id!(params[:seller_id])
            authorize_parent!(@parent)
          end

          private

          def seller
            @parent
          end

          # Through the store's own requirements: an id from elsewhere is a
          # 404 here rather than a waiver written against another
          # marketplace's checklist.
          def requirement_from_params
            current_store.seller_requirements.find_by_prefix_id!(params[:requirement_id])
          end

          def run_workflow(workflow)
            result = workflow.call(
              submission: @resource,
              reviewed_by: try_spree_current_user,
              review_note: params[:review_note]
            )

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end
        end
      end
    end
  end
end
