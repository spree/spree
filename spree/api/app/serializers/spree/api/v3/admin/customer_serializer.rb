module Spree
  module Api
    module V3
      module Admin
        # Admin API Customer Serializer
        # Full customer data including admin-only fields
        class CustomerSerializer < V3::CustomerSerializer
          typelize login: [:string, nullable: true],
                   last_sign_in_at: [:string, nullable: true], current_sign_in_at: [:string, nullable: true],
                   sign_in_count: :number, failed_attempts: :number,
                   last_sign_in_ip: [:string, nullable: true], current_sign_in_ip: [:string, nullable: true]

          # Admin-only attributes
          attributes :login,
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

          # Override inherited associations to use admin serializers
          many :addresses, resource: Spree.api.admin_address_serializer, if: proc { expand?('addresses') }
          one :bill_address, key: :default_billing_address, resource: Spree.api.admin_address_serializer, if: proc { expand?('default_billing_address') }
          one :ship_address, key: :default_shipping_address, resource: Spree.api.admin_address_serializer, if: proc { expand?('default_shipping_address') }

          many :orders,
               resource: Spree.api.admin_order_serializer,
               if: proc { expand?('orders') }
        end
      end
    end
  end
end
