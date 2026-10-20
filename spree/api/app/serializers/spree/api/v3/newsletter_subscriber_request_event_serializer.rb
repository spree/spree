module Spree
  module Api
    module V3
      # The event shape for `newsletter_subscriber.subscription_requested` and
      # `newsletter_subscriber.unsubscribe_requested`: the tokens a storefront
      # needs to build the confirmation or unsubscribe link itself.
      # `verification_token` is present only on a subscription request.
      class NewsletterSubscriberRequestEventSerializer < BaseSerializer
        typelize email: :string, unsubscribe_token: :string, verification_token: [:string, optional: true],
                 store_id: [:string, nullable: true], customer_id: [:string, nullable: true],
                 redirect_url: [:string, optional: true]

        attributes :email

        attribute :verification_token, if: proc { params[:include_verification_token] }, &:verification_token

        attribute :unsubscribe_token do |subscriber|
          subscriber.generate_token_for(:unsubscribe)
        end

        attribute :store_id do
          params[:store]&.prefixed_id
        end

        attribute :customer_id do |subscriber|
          subscriber.customer&.prefixed_id
        end

        attribute :redirect_url, if: proc { params[:redirect_url].present? } do
          params[:redirect_url]
        end
      end
    end
  end
end
