module Spree
  module Emails
    class CustomerSerializer < Spree::Api::V3::CustomerSerializer
      _attributes.delete(:custom_fields)

      without_display_money

      many :addresses, resource: Spree::Emails::AddressSerializer
      one :bill_address, key: :default_billing_address, resource: Spree::Emails::AddressSerializer
      one :ship_address, key: :default_shipping_address, resource: Spree::Emails::AddressSerializer

      one :newsletter_subscriber, resource: Spree::Emails::NewsletterSubscriberSerializer do |user, params|
        user.newsletter_subscriber(params&.dig(:store) || Spree::Current.store)
      end

      many :customer_groups,
           proc { |groups, params| groups.for_store(params&.dig(:store) || Spree::Current.store) },
           resource: Spree::Emails::CustomerGroupSerializer
    end
  end
end
