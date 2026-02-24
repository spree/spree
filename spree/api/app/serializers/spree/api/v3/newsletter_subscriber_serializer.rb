# frozen_string_literal: true

module Spree
  module Api
    module V3
      class NewsletterSubscriberSerializer < BaseSerializer
        typelize email: :string, verified: :boolean,
                 verified_at: [:string, nullable: true],
                 user_id: [:string, nullable: true]

        attributes :email, created_at: :iso8601, updated_at: :iso8601

        attribute :verified do |subscriber|
          subscriber.verified?
        end

        attribute :verified_at do |subscriber|
          subscriber.verified_at&.iso8601
        end

        attribute :user_id do |subscriber|
          subscriber.user&.prefixed_id
        end
      end
    end
  end
end
