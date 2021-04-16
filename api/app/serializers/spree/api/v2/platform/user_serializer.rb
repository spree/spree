module Spree
  module Api
    module V2
      module Platform
        class UserSerializer < BaseSerializer
          set_type :user

          attributes :email, :created_at, :updated_at

          has_one :bill_address,
                  record_type: :address,
                  serializer: :address

          has_one :ship_address,
                  record_type: :address,
                  serializer: :address
        end
      end
    end
  end
end
