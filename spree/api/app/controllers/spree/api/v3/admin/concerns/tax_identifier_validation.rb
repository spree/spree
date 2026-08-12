module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # The re-check action, shared by the two places a registration is
          # managed: nested under a customer, and nested under a company.
          #
          # Separate from the number-changed path, which the model stamps and a
          # subscriber queues. This is staff asking "is it still valid now" — a
          # number verified last year may have been deregistered since — so it
          # queues a check without the number having changed.
          module TaxIdentifierValidation
            extend ActiveSupport::Concern

            def validate
              authorize_resource!(@resource, :update)

              unless @resource.validatable?
                render_error(
                  code: 'tax_id_not_validatable',
                  message: "No validator is registered for tax identifier kind '#{@resource.kind}'",
                  status: :unprocessable_content
                )
                return
              end

              # Marked pending before the job is queued, not after: the job can
              # finish first, and writing 'pending' afterwards would bury the
              # verdict it just recorded.
              @resource.update_columns(validation_status: 'pending', validated_at: nil, updated_at: Time.current)
              Spree::TaxIdentifiers::ValidateJob.perform_later(@resource.id)

              render json: serialize_resource(@resource.reload), status: :accepted
            end
          end
        end
      end
    end
  end
end
