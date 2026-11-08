module Spree
  module Emails
    class NewsletterSubscriberSerializer < Spree::Api::V3::NewsletterSubscriberSerializer
      _attributes.delete(:custom_fields)
    end
  end
end
