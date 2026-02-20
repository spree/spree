module Spree
  module Api
    module V3
      module Admin
        # Admin API Customer Serializer
        # Full customer data including admin-only fields
        class CustomerSerializer < V3::CustomerSerializer
          typelize phone: [:string, nullable: true], login: [:string, nullable: true],
                   accepts_email_marketing: :boolean,
                   last_sign_in_at: [:string, nullable: true], current_sign_in_at: [:string, nullable: true],
                   sign_in_count: :number, failed_attempts: :number,
                   last_sign_in_ip: [:string, nullable: true], current_sign_in_ip: [:string, nullable: true]

          # Admin-only attributes
          attributes :phone, :login, :accepts_email_marketing,
                     last_sign_in_at: :iso8601, current_sign_in_at: :iso8601

          attribute :sign_in_count do |user|
            user.sign_in_count
          end

          attribute :failed_attempts do |user|
            user.failed_attempts
          end

          attribute :last_sign_in_ip do |user|
            user.last_sign_in_ip
          end

          attribute :current_sign_in_ip do |user|
            user.current_sign_in_ip
          end

          many :orders,
               resource: Spree.api.admin_order_serializer,
               if: proc { params[:includes]&.include?('orders') }

          # TODO: Add store_credits association when Admin API is implemented
        end
      end
    end
  end
end
