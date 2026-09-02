module Spree
  module Api
    module V3
      module Store
        # Hands a completed export to the person who asked for it.
        #
        # Token-addressed rather than session-authenticated, and unauthenticated
        # for the same reason the digital-link download is: the link arrives by
        # email and has to work when clicked, including from a device that was
        # never signed in. The token is the credential — long, unguessable, only
        # ever sent to the address that made the request, and dead once the
        # request expires.
        class DataRequestDownloadsController < Store::BaseController
          # Lets the Disk service build absolute URLs from the current request;
          # remote services (S3 et al.) sign without it.
          include ActiveStorage::SetCurrent

          allow_guest_storefront_access!
          skip_before_action :authenticate_api_key!

          # GET /api/v3/store/data_requests/:token/download
          def show
            data_request = Spree::DataRequest.find_by(download_token: params[:token])

            unless data_request&.downloadable?
              return render_error(
                code: 'data_request_expired',
                message: Spree.t('data_request_errors.download_unavailable'),
                status: :forbidden
              )
            end

            # The response points at a person's whole personal-data export, so
            # no shared cache or browser history should hold on to it.
            response.headers['Cache-Control'] = 'no-store'

            redirect_to(
              data_request.export_file.url(
                expires_in: 5.minutes,
                disposition: :attachment,
                filename: ActiveStorage::Filename.new("#{data_request.number.downcase}.json")
              ),
              allow_other_host: true
            )
          end
        end
      end
    end
  end
end
