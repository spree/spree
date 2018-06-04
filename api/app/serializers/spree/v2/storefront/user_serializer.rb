module Spree
  module V2
    module Storefront
      class UserSerializer < BaseSerializer
        set_type :user
        attributes :id, :email
      end
    end
  end
end
