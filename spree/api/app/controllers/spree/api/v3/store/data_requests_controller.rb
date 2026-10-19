module Spree
  module Api
    module V3
      module Store
        # A data request as seen by whoever holds its confirmation token: the
        # person reading mail at the address the request names.
        #
        # Token-addressed rather than session-authenticated, because the link
        # arrives by email and may be opened on a device that was never signed
        # in. It is the only place the API shows the export link, since the
        # token is what reached the address the request names.
        class DataRequestsController < Store::BaseController
          allow_guest_storefront_access!

          # GET /api/v3/store/data_requests/:token
          def show
            return render_confirmation_invalid(status: :not_found) unless data_request

            render json: serialize_resource(data_request)
          end

          protected

          def serializer_class
            Spree.api.data_request_serializer
          end

          def serializer_params
            super.merge(download_url_visible: true)
          end

          private

          def data_request
            return @data_request if defined?(@data_request)

            token = params[:token].presence
            @data_request = token && Spree::DataRequest.for_store(current_store).find_by_token_for(:confirmation, token)
          end

          def render_confirmation_invalid(status:)
            render_error(
              code: ERROR_CODES[:invalid_token],
              message: I18n.t('spree.data_request_errors.confirmation_invalid'),
              status: status
            )
          end
        end
      end
    end
  end
end
