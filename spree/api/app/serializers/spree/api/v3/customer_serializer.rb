module Spree
  module Api
    module V3
      # Store API Customer Serializer
      # Customer-facing user data
      class CustomerSerializer < BaseSerializer
        typelize email: :string, first_name: [:string, nullable: true], last_name: [:string, nullable: true],
                 full_name: :string,
                 phone: [:string, nullable: true], accepts_email_marketing: :boolean,
                 available_store_credit_total: :string, display_available_store_credit_total: :string,
                 default_billing_address: { nullable: true }, default_shipping_address: { nullable: true },
                 newsletter_subscriber: { nullable: true }

        attributes :email, :first_name, :last_name, :phone, :accepts_email_marketing

        attribute :full_name do |user|
          user.full_name.presence || user.email
        end

        attribute :available_store_credit_total do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          currency = params&.dig(:currency) || Spree::Current.currency || store&.default_currency
          user.total_available_store_credit(currency, store).to_s
        end

        attribute :display_available_store_credit_total do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          currency = params&.dig(:currency) || Spree::Current.currency || store&.default_currency
          Spree::Money.new(user.total_available_store_credit(currency, store), currency: currency).to_s
        end

        many :addresses, resource: proc { Spree.api.address_serializer }
        one :bill_address, key: :default_billing_address, resource: proc { Spree.api.address_serializer }
        one :ship_address, key: :default_shipping_address, resource: proc { Spree.api.address_serializer }

        one :newsletter_subscriber, resource: proc { Spree.api.newsletter_subscriber_serializer } do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          user.newsletter_subscriber(store)
        end

        # Membership signal for storefront branching (e.g. wholesale approval);
        # scoped to the request store (params first — Spree::Current.store falls
        # back to the DEFAULT store, wrong on sibling stores' domains) so other
        # stores' memberships never leak.
        many :customer_groups,
             proc { |groups, params| groups.for_store(params&.dig(:store) || Spree::Current.store) },
             resource: proc { Spree.api.customer_group_serializer }
      end
    end
  end
end
