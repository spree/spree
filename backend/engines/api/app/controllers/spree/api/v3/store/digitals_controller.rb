module Spree
  module Api
    module V3
      module Store
        class DigitalsController < Store::BaseController
          skip_before_action :authenticate_api_key!
          before_action :set_resource

          # GET /api/v3/store/digitals/:token
          def show
            if @resource.authorize!
              send_data @resource.digital.attachment.download,
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

          private

          def set_resource
            @resource = digital_link_scope.find_by!(token: params[:token])
          end

          def digital_link_scope
            current_store.digital_links
          end
        end
      end
    end
  end
end
