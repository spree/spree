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

        prefixed_id_attributes :customer
      end
    end
  end
end
