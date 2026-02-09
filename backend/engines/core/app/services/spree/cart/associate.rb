module Spree
  module Cart
    class Associate
      prepend Spree::ServiceModule::Base

      def call(guest_order:, user:)
        if guest_order.user.nil?
          guest_order.associate_user!(user)
          success(guest_order)
        else
          failure(guest_order, 'Already assigned to a user')
        end
      end
    end
  end
end
