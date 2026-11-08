module Spree
  module Emails
    module Samples
      class DataRequestConfirmation < Base
        def variables
          {
            kind: Spree::DataRequest::ACCESS,
            confirmation_url: placeholder_url('account/data-requests/confirm'),
            expires_at: Spree::DataRequest::CONFIRMATION_WINDOW.from_now.iso8601
          }
        end
      end
    end
  end
end
