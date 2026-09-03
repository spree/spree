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

            # Streamed rather than redirected to a storage URL. A redirect only
            # carries `no-store` on itself — the browser then fetches the
            # storage response separately, under whatever cache policy that
            # bucket happens to have, and a person's entire personal-data
            # export is not something to leave to that. Streaming also keeps
            # the file behind this token check rather than behind a URL that
            # outlives the request.
            response.headers['Cache-Control'] = 'no-store'

            send_data(
              data_request.export_file.download,
              filename: "#{data_request.number.downcase}.json",
              type: 'application/json',
              disposition: 'attachment'
            )
          end
        end
      end
    end
  end
end
