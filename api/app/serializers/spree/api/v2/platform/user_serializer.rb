module Spree
  module Api
    module V2
      module Platform
        class UserSerializer < BaseSerializer
          set_type :user

          attributes :email, :created_at, :updated_at

          attribute :average_order_value do |user, params|
            user.report_values_for(:average_order_value, params[:store])
          end

          attribute :lifetime_value do |user, params|
            user.report_values_for(:lifetime_value, params[:store])
          end

          attribute :store_credits do |user, params|
            user.available_store_credits(params[:store])
          end

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
