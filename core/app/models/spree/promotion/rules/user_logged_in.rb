module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule

        def eligible?(order, options = {})
          # this is tricky.  We couldn't use any of the devise methods since we aren't in the controller.
          # we need to rely on the controller already having done this for us.

          # The thinking is that the controller should have some sense of what state
          # we should be in before firing events,
          # so the controller will have to set this field.

          return options && options[:user_signed_in]
        end

      end
    end
  end
end
