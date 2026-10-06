module Spree
  module Api
    module V3
      # The event shape for `customer.password_reset_requested`,
      # `admin_user.password_reset_requested` and
      # `seller_user.password_reset_requested`: what a storefront or back office
      # needs to email the reset link itself. `reset_token` is a live credential,
      # so these events reach only endpoints that name them.
      class PasswordResetRequestedEventSerializer < BaseSerializer
        typelize email: :string, reset_token: :string, store_id: [:string, nullable: true],
                 redirect_url: [:string, optional: true]

        attributes :email

        attribute :reset_token do
          params[:reset_token]
        end

        attribute :store_id do
          params[:store]&.prefixed_id
        end

        attribute :redirect_url, if: proc { params[:redirect_url].present? } do
          params[:redirect_url]
        end
      end
    end
  end
end
