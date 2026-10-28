# frozen_string_literal: true

module Spree
  module Api
    module V3
      class NewsletterSubscriberSerializer < BaseSerializer
        typelize email: :string, verified: :boolean,
                 verified_at: [:string, nullable: true],
                 customer_id: [:string, nullable: true]

        attributes :email, created_at: :iso8601, updated_at: :iso8601

        attribute :verified, &:verified?

        attribute :verified_at do |subscriber|
          subscriber.verified_at&.iso8601
        end

        # Shown to the account's owner only: for anyone else, posting an email
        # must not tell them whether an account exists for it.
        attribute :customer_id do |subscriber|
          subscriber.customer&.prefixed_id if current_user && subscriber.customer_id == current_user.id
        end

        expandable_custom_fields
      end
    end
  end
end
