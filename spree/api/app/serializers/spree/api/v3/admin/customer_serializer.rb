module Spree
  module Api
    module V3
      module Admin
        # Admin API Customer Serializer
        # Full customer data including admin-only fields
        class CustomerSerializer < V3::CustomerSerializer
          typelize login: [:string, nullable: true],
                   last_sign_in_at: [:string, nullable: true], current_sign_in_at: [:string, nullable: true],
                   sign_in_count: :number, failed_attempts: :number,
                   last_sign_in_ip: [:string, nullable: true], current_sign_in_ip: [:string, nullable: true],
                   tags: [:string, multi: true],
                   internal_note_html: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   orders_count: :number,
                   total_spent: :string,
                   display_total_spent: :string,
                   last_order_completed_at: [:string, nullable: true],
                   default_billing_address_id: [:string, nullable: true],
                   default_shipping_address_id: [:string, nullable: true],
                   customer_group_ids: [:string, multi: true]

          # Admin-only attributes
          attributes :login, :metadata,
                     last_sign_in_at: :iso8601, current_sign_in_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :sign_in_count do |user|
            user.sign_in_count
          end

          attribute :failed_attempts do |user|
            user.failed_attempts
          end

          attribute :last_sign_in_ip do |user|
            user.last_sign_in_ip
          end

          attribute :current_sign_in_ip do |user|
            user.current_sign_in_ip
          end

          attribute :tags do |user|
            user.tags.map(&:name) # not pluck as we preload tags
          end

          attribute :internal_note_html do |user|
            user.respond_to?(:internal_note) ? user.internal_note&.body&.to_s.presence : nil
          end

          attribute :default_billing_address_id do |user|
            user.bill_address&.prefixed_id
          end

          attribute :default_shipping_address_id do |user|
            user.ship_address&.prefixed_id
          end

          # Order aggregates: prefer attributes precomputed on the scope (see
          # CustomersController#scope) to avoid N+1 on list endpoints. Fall
          # back to per-user queries when not preloaded (e.g. show endpoint
          # for a freshly loaded record).
          attribute :orders_count do |user|
            user.attributes['orders_count']&.to_i || user.orders.complete.count
          end

          attribute :total_spent do |user|
            (user.attributes['total_spent'] || user.orders.complete.sum(:total)).to_s
          end

          attribute :display_total_spent do |user|
            amount = user.attributes['total_spent'] || user.orders.complete.sum(:total)
            currency = Spree::Current.currency || Spree::Current.store&.default_currency || Spree::Config[:currency]
            Spree::Money.new(amount, currency: currency).to_s
          end

          attribute :last_order_completed_at do |user|
            value = user.attributes.key?('last_order_completed_at') ? user.attributes['last_order_completed_at'] : user.orders.complete.maximum(:completed_at)
            value.respond_to?(:iso8601) ? value.iso8601 : value
          end

          # Override inherited associations to use admin serializers
          many :addresses, resource: proc { Spree.api.admin_address_serializer }, if: proc { expand?('addresses') }
          one :bill_address, key: :default_billing_address, resource: proc { Spree.api.admin_address_serializer }, if: proc { expand?('default_billing_address') }
          one :ship_address, key: :default_shipping_address, resource: proc { Spree.api.admin_address_serializer }, if: proc { expand?('default_shipping_address') }

          # Override the inherited always-on store association to gate it behind
          # expand? — the admin customers index serializes many rows and an
          # always-on association would fire one query per row.
          one :newsletter_subscriber,
              resource: proc { Spree.api.admin_newsletter_subscriber_serializer },
              if: proc { expand?('newsletter_subscriber') } do |user, params|
            store = params&.dig(:store) || Spree::Current.store
            user.newsletter_subscriber(store)
          end

          many :orders,
               resource: proc { Spree.api.admin_order_serializer },
               if: proc { expand?('orders') }

          many :store_credits,
               resource: proc { Spree.api.admin_store_credit_serializer },
               if: proc { expand?('store_credits') }

          attribute :customer_group_ids do |user|
            user.customer_groups.map(&:prefixed_id)
          end

          many :customer_groups,
               resource: proc { Spree.api.admin_customer_group_serializer },
               if: proc { expand?('customer_groups') }
        end
      end
    end
  end
end
