module Spree
  module V2
    module Storefront
      class UserSerializer < BaseSerializer
        set_type   :user

        attributes :email
      end
    end
  end
end
