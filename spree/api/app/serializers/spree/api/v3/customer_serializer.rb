module Spree
  module Api
    module V3
      # Store API Customer Serializer
      # Customer-facing user data
      class CustomerSerializer < BaseSerializer
        typelize email: :string, first_name: [:string, nullable: true], last_name: [:string, nullable: true],
                 phone: [:string, nullable: true], accepts_email_marketing: :boolean,
                 available_store_credit_total: :string, display_available_store_credit_total: :string,
                 default_billing_address: { nullable: true }, default_shipping_address: { nullable: true }

        attributes :email, :first_name, :last_name, :phone, :accepts_email_marketing,
                   created_at: :iso8601, updated_at: :iso8601

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

        many :addresses, resource: Spree.api.address_serializer
        one :bill_address, key: :default_billing_address, resource: Spree.api.address_serializer
        one :ship_address, key: :default_shipping_address, resource: Spree.api.address_serializer
      end
    end
  end
end
