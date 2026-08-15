module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A company's exemption evidence. Accepting one is a decision, so it
          # runs through the verify workflow rather than a status write, and a
          # verified certificate is revoked rather than deleted.
          class TaxExemptionCertificatesController < BaseController
            include ActiveStorage::SetCurrent

            before_action :authorize_parent_access!
            # Re-declaring the filter replaces the inherited options, so the
            # standard actions have to be listed alongside the custom ones.
            before_action :set_resource, only: [:show, :update, :destroy, :verify, :revoke, :download]

            # A tampered signed id would otherwise surface as a 500.
            rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_invalid_signature

            # PATCH /api/v3/admin/companies/:company_id/tax_exemption_certificates/:id/verify
            def verify
              result = Spree.tax_exemption_certificate_verify_workflow.call(
                certificate: @resource,
                verified_by: try_spree_current_user
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            # PATCH .../:id/revoke — withdrawing evidence that was accepted.
            def revoke
              if @resource.update(status: 'revoked')
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # GET .../:id/download — streamed rather than redirected, so the
            # document is never reachable without admin credentials.
            def download

              unless @resource.document.attached?
                return render_error(
                  code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                  message: 'Certificate has no attached document',
                  status: :unprocessable_content
                )
              end

              send_data(
                @resource.document.download,
                filename: @resource.document.filename.to_s,
                type: @resource.document.content_type || 'application/octet-stream',
                disposition: 'attachment'
              )
            end

            protected

            # Fetching the document is a read of the certificate, so it takes the
            # read scope and the :show ability rather than being classed as a
            # write because it isn't index or show. Without this a key holding
            # read_customers is refused its own certificate.
            READ_ACTIONS = %w[index show download].freeze

            def read_actions
              READ_ACTIONS
            end

            def action_kind
              READ_ACTIONS.include?(action_name) ? 'read' : 'write'
            end

            def model_class
              Spree::TaxExemptionCertificate
            end

            def serializer_class
              Spree.api.admin_tax_exemption_certificate_serializer
            end

            def scope
              @parent.tax_exemption_certificates
            end

            def parent_association
              :tax_exemption_certificates
            end

            def collection_includes
              [{ document_attachment: :blob }]
            end

            # `document` is an ActiveStorage signed blob id from
            # POST /api/v3/admin/direct_uploads.
            def permitted_params
              params.permit(:certificate_number, :reason_code, :issuing_authority,
                            :issued_at, :expires_at, :country_code, :state_code, :document,
                            metadata: {})
            end

            def build_resource
              super.tap { |certificate| certificate.status ||= 'pending' }
            end

            # The custom actions are not permissions of their own: accepting or
            # withdrawing is updating, fetching the document is reading.
            def authorize_resource!(resource = @resource, action = action_name.to_sym)
              mapped = case action
                       when :verify, :revoke then :update
                       when :download then :show
                       else action
                       end

              authorize!(mapped, resource)
            end

            private

            def render_invalid_signature
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Invalid document signed id',
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
