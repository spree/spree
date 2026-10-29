# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin API Newsletter Subscriber Serializer
        # Back-office surface, nested under the admin customer serializer. Extends the
        # customer-facing serializer so public fields stay in sync.
        class NewsletterSubscriberSerializer < V3::NewsletterSubscriberSerializer
          prefixed_id_attributes :customer

          expandable_custom_fields admin: true
        end
      end
    end
  end
end
