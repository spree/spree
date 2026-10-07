module Spree
  module Emails
    module Samples
      class PasswordReset < Base
        def variables
          {
            customer: data(Spree.customer_class.new(first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com'),
                           Spree.api.customer_serializer),
            reset_url: placeholder_url('account/reset-password')
          }
        end
      end
    end
  end
end
