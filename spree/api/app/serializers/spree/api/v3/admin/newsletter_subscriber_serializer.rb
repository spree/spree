# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin API Newsletter Subscriber Serializer
        # Back-office surface, nested under the admin customer serializer. Extends the
        # customer-facing serializer so public fields stay in sync.
        class NewsletterSubscriberSerializer < V3::NewsletterSubscriberSerializer
        end
      end
    end
  end
end
