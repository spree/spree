module Spree
  module Api
    module V3
      module Store
        class DigitalLinksController < Store::BaseController
          # Lets the Disk service build absolute URLs from the current request;
          # remote services (S3 et al.) sign without it.
          include ActiveStorage::SetCurrent

          allow_guest_storefront_access!
          skip_before_action :authenticate_api_key!
          before_action :set_resource

          # GET /api/v3/store/digital_links/:token
          #
          # Redirects to a short-lived signed storage URL rather than streaming
          # the file, so a large download does not hold a web worker open for
          # its duration.
          def show
            if (download_url = authorized_download_url)
              @resource.publish_event('digital_link.downloaded')

              redirect_to download_url, allow_other_host: true
            else
              render_error(
                code: ERROR_CODES[:digital_link_expired],
                message: 'Download link expired or invalid',
                status: :forbidden
              )
            end
          end

          private

          # Everything that can refuse the download is settled before the click
          # is spent, so a missing file never burns a customer's allowance.
          def authorized_download_url
            return unless @resource.digital_asset.downloadable?

            window = signed_url_window
            return if window <= 0
            return unless @resource.authorize!

            @resource.digital_asset.download_url(expires_in: window)
          end

          # The signed URL is a bearer credential, so it must never outlive the
          # link that authorized it — otherwise an expired link keeps handing
          # out working URLs for the rest of the store's window.
          def signed_url_window
            window = current_store.preferred_digital_asset_link_expire_time.seconds
            return window unless (expiry = @resource.expires_at)

            [window, expiry - Time.current].min
          end

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
