module Spree
  module Api
    module V3
      module Admin
        class AdminUserSerializer < BaseSerializer
          typelize email: :string,
                   first_name: [:string, nullable: true],
                   last_name: [:string, nullable: true]

          attributes :email, :first_name, :last_name,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
