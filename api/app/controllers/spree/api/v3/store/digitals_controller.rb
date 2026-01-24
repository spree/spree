module Spree
  module Api
    module V3
      module Store
        class DigitalsController < Store::ResourceController
          # GET  /api/v3/store/digitals/:id?token=...
          def show
            if @resource.authorize!
              send_file @resource.digital.attachment.path,
                        filename: @resource.digital.attachment.filename.to_s,
                        type: @resource.digital.attachment.content_type
            else
              render_error(
                code: ERROR_CODES[:digital_link_expired],
                message: 'Download link expired or invalid',
                status: :forbidden
              )
            end
          end

          protected

          def model_class
            Spree::DigitalLink
          end

          def serializer_class
            Spree.api.digital_link_serializer
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action, resource, digital_token)
          end

          def digital_token
            request.headers['X-Spree-Digital-Token'].presence || params[:token]
          end
        end
      end
    end
  end
end
