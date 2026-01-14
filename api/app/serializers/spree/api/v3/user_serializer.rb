module Spree
  module Api
    module V3
      class UserSerializer < BaseSerializer
        attributes :id, :email, :first_name, :last_name,
                   created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
