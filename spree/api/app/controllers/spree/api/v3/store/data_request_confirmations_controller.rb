module Spree
  module Api
    module V3
      module Store
        # Confirms a request a customer raised, from the page the emailed link
        # opens. The page calls this when the person presses its button, never
        # on load: some mail scanners open links and run the page's scripts.
        class DataRequestConfirmationsController < DataRequestsController
          # POST /api/v3/store/data_requests/:token/confirmation
          def create
            return render_confirmation_invalid(status: :unprocessable_content) unless data_request

            result = Spree::DataRequests::Confirm.call(data_request: data_request)

            return render_confirmation_invalid(status: :unprocessable_content) unless result.success?

            render json: serialize_resource(result.value)
          end
        end
      end
    end
  end
end
