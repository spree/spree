module Spree
  module Emails
    module Samples
      class NewsletterConfirmation < Base
        def variables
          { confirmation_url: placeholder_url('newsletter/confirm') }
        end
      end
    end
  end
end
