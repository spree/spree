# frozen_string_literal: true

module Spree
  module Events
    class NewsletterSubscriberSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          email: resource.email,
          verified: resource.verified?,
          verified_at: timestamp(resource.verified_at),
          user_id: resource.user_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
