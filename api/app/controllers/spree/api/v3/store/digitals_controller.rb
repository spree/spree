module Spree
  module Api
    module V3
      module Store
        class DigitalsController < BaseController
          # Public endpoint - access via token

          # GET  /api/v3/store/digitals/:token
          def download
            digital_link = Spree::DigitalLink.find_by!(token: params[:token])

            if digital_link.authorize!
              send_file digital_link.digital.attachment.path,
                        filename: digital_link.digital.attachment.filename.to_s,
                        type: digital_link.digital.attachment.content_type
            else
              render json: { error: 'Download link expired or invalid' }, status: :forbidden
            end
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'Digital download not found' }, status: :not_found
          end
        end
      end
    end
  end
end
