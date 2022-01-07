module Spree
  module Api
    module V2
      module Storefront
        class DigitalsController < ::Spree::Api::V2::ResourceController
          def download
            if attachment.present?
              if digital_link.authorize!
                if defined?(ActiveStorage::Service::DiskService) && ActiveStorage::Blob.service.instance_of?(ActiveStorage::Service::DiskService)
                  # The asset is hosted on disk, use send_file.

                  send_file(
                    ActiveStorage::Blob.service.path_for(attachment.key),
                    filename: attachment.filename.to_s,
                    type: attachment.content_type.to_s,
                    status: :ok
                  ) and return

                else
                  # The asset is hosted on a 3rd party service, use an expiring url with disposition: 'attachment'.

                  redirect_to attachment.url(
                    expires_in: current_store.digital_asset_link_expire_time.seconds,
                    disposition: 'attachment',
                    host: digital_attachment_host
                  ) and return

                end
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

          def digital_attachment_host
            current_store.formatted_url
          end
        end
      end
    end
  end
end
