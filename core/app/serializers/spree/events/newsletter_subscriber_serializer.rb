# frozen_string_literal: true

module Spree
  module Events
    class NewsletterSubscriberSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          email: resource.email,
          verified: resource.verified?,
          verified_at: timestamp(resource.verified_at),
          user_id: association_prefix_id(:user),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
