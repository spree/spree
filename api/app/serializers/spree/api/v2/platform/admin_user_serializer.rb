module Spree
  module Api
    module V2
      module Platform
        class AdminUserSerializer < UserSerializer
          set_type :admin_user
        end
      end
    end
  end
end
