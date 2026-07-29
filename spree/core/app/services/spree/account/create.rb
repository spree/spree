module Spree
  module Account
    class Create
      prepend Spree::ServiceModule::Base

      def call(user_params: {})
        user = Spree.customer_class.new(user_params)

        if user.save
          success(user)
        else
          failure(user)
        end
      end
    end
  end
end
