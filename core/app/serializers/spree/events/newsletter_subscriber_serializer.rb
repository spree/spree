# frozen_string_literal: true

module Spree
  module Events
    class NewsletterSubscriberSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          email: resource.email,
          verified: resource.verified?,
          verified_at: timestamp(resource.verified_at),
          user_id: public_id(resource.user),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
