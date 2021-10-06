module Spree
  module Api
    module V2
      module Storefront
        class DigitalsController < ::Spree::Api::V2::ResourceController
          def download
            if attachment.present?
              if digital_link.authorize!
                send_file(
                  ActiveStorage::Blob.service.path_for(attachment.key),
                  filename: attachment.record.attachment_file_name,
                  type: attachment.record.attachment_content_type,
                  status: :ok
                ) and return
              end
            else
              Rails.logger.error I18n.t('spree.api.v2.digitals.missing_file')
            end

            render json: { error: I18n.t('spree.api.v2.digitals.unauthorized') }, status: 403
          end

          private

          def model_class
            Spree::Digital
          end

          def digital_link
            @digital_link ||= DigitalLink.find_by!(token: params[:token])
          end

          def attachment
            @attachment ||= digital_link.digital.try(:attachment) if digital_link.present?
          end
        end
      end
    end
  end
end
