module Spree
  module Api
    module V3
      module Admin
        # Admin API User Serializer
        # Full user data including admin-only fields
        class UserSerializer < V3::UserSerializer
          typelize phone: 'string | null', login: 'string | null',
                   accepts_email_marketing: :boolean,
                   last_sign_in_at: 'string | null', current_sign_in_at: 'string | null',
                   sign_in_count: :number, failed_attempts: :number,
                   last_sign_in_ip: 'string | null', current_sign_in_ip: 'string | null',
                   public_metadata: 'Record<string, unknown> | null',
                   private_metadata: 'Record<string, unknown> | null'

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

          attribute :public_metadata do |user|
            user.public_metadata
          end

          attribute :private_metadata do |user|
            user.private_metadata
          end

          many :orders,
               resource: Spree::Api::V3::Admin::OrderSerializer,
               if: proc { params[:includes]&.include?('orders') }

          # TODO: Add store_credits association when Admin API is implemented
        end
      end
    end
  end
end
