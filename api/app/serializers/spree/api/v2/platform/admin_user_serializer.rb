module Spree
  module Api
    module V2
      module Platform
        class AdminUserSerializer < UserSerializer
          set_type :user
        end
      end
    end
  end
end
