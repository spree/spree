module Spree
  module Api
    module V3
      module Seller
        # What a seller submits about one requirement: an attestation they
        # tick, a document they upload, a reference they paste.
        #
        # Create only. A submission records what was said and when — editing
        # one would rewrite that history, and withdrawing is not a thing a
        # seller does: they submit again, and the latest one counts. Accepting,
        # rejecting and waiving belong to the operator, on their own branch.
        class RequirementSubmissionsController < Seller::BaseController
          scoped_resource :seller_profile

          before_action :set_requirement, only: [:create]
          before_action :set_submission, only: [:download]

          # POST /api/v3/seller/requirements/:requirement_id/submissions
          def create
            result = Spree.seller_requirement_submission_create_workflow.call(
              seller: current_seller,
              requirement: @requirement,
              note: params[:note],
              reference: params[:reference],
              file: params[:file],
              submitted_by: try_spree_current_user
            )

            return render_service_error(result.error) unless result.success?

            render json: serialize(result.value), status: :created
          end

          # GET /api/v3/seller/requirement_submissions/:id/download
          #
          # Authorized per request rather than served from a storage URL:
          # these are identity documents, and a link that works for anyone
          # holding it is not a property we want them to have.
          def download
            unless @submission.file.attached?
              return render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t(:seller_submission_no_file),
                status: :unprocessable_content
              )
            end

            send_data(
              @submission.file.download,
              filename: @submission.file.filename.to_s,
              type: @submission.file.content_type,
              disposition: 'attachment'
            )
          end

          protected

          def read_actions
            %w[download]
          end

          private

          # Through the store's own checklist: a requirement id belonging to
          # another marketplace 404s rather than letting a seller submit
          # against someone else's configuration.
          def set_requirement
            @requirement = current_store.seller_requirements.find_by_prefix_id!(params[:requirement_id])
          end

          # Through the seller, so one seller can never read another's
          # documents.
          def set_submission
            @submission = current_seller.requirement_submissions.find_by_prefix_id!(params[:id])
          end

          def serialize(submission)
            Spree.api.seller_requirement_submission_serializer.new(
              submission, params: { store: current_store }
            ).to_h
          end
        end
      end
    end
  end
end
