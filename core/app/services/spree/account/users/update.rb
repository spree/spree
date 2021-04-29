module Spree
  module Account
    module Users
      class Update
        prepend Spree::ServiceModule::Base

        def call(user:, user_params:)
          if user.update(user_params)
            success(user)
          else
            failure(user)
          end
        end
      end
    end
  end
end
