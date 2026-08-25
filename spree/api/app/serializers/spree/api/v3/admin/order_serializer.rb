module Spree
  module Api
    module V3
      module Admin
        # Admin API Order Serializer
        # Full order data including admin-only fields
        class OrderSerializer < V3::OrderSerializer
          include Concerns::ExternalReferencesAttribute


          typelize company_id: [:string, nullable: true],
                   company_name: [:string, nullable: true],
                   seller_id: [:string, nullable: true],
                   order_group_id: [:string, nullable: true]

          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize item_total: [:string, nullable: false], display_item_total: [:string, nullable: false],
                   delivery_total: [:string, nullable: false], display_delivery_total: [:string, nullable: false],
                   adjustment_total: [:string, nullable: false], display_adjustment_total: [:string, nullable: false],
                   discount_total: [:string, nullable: false], display_discount_total: [:string, nullable: false],
                   tax_total: [:string, nullable: false], display_tax_total: [:string, nullable: false],
                   included_tax_total: [:string, nullable: false], display_included_tax_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false], display_additional_tax_total: [:string, nullable: false],
                   store_credit_total: [:string, nullable: false], display_store_credit_total: [:string, nullable: false],
                   gift_card_total: [:string, nullable: false], display_gift_card_total: [:string, nullable: false],
                   fee_total: [:string, nullable: false], display_fee_total: [:string, nullable: false],
                   total: [:string, nullable: false], display_total: [:string, nullable: false],
                   amount_due: [:string, nullable: false], display_amount_due: [:string, nullable: false]

          typelize status: :string,
                   last_ip_address: [:string, nullable: true],
                   considered_risky: :boolean, confirmation_delivered: :boolean,
                   store_owner_notification_delivered: :boolean,
                   internal_note: [:string, nullable: true], internal_note_html: [:string, nullable: true],
                   approver_id: [:string, nullable: true],
                   canceler_id: [:string, nullable: true], created_by_id: [:string, nullable: true],
                   customer_id: [:string, nullable: true],
                   preferred_stock_location_id: [:string, nullable: true],
                   canceled_at: [:string, nullable: true], approved_at: [:string, nullable: true],
                   payment_total: :string, display_payment_total: :string,
                   tags: [:string, multi: true],
                   metadata: 'Record<string, unknown>'

          # Admin-only attributes
          attributes :status, :last_ip_address, :considered_risky,
                     :confirmation_delivered, :store_owner_notification_delivered,
                     :payment_total, :display_payment_total, :metadata,
                     canceled_at: :iso8601, approved_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preferred_stock_location_id do |order|
            order.preferred_stock_location&.prefixed_id
          end

          # Which company node the order is for, so the dashboard can show and
          # change it. Read back from the column rather than #resolved_company:
          # a placed order must report what it was stamped with.
          attribute :company_id do |order|
            order.company&.prefixed_id
          end

          attribute :company_name do |order|
            order.company&.name
          end

          # Whose sale this is — nil on the operator's own goods. The full
          # profile is `?expand=seller`.
          attribute :seller_id do |order|
            order.seller&.prefixed_id
          end

          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') }

          # The checkout this order was placed in, when it was placed alongside
          # others.
          #
          # Deliberately an id and no expand: the group serializer renders the
          # orders it holds, so expanding it from an order would render this
          # order again inside itself. A client wanting the group fetches
          # /order_groups/:id, which is what that endpoint is for.
          attribute :order_group_id do |order|
            Spree::OrderGroup.prefixed_id_for(order.order_group_id)
          end

          attribute :tags do |order|
            order.tags.map(&:name) # not pluck as we preload tags
          end

          attribute :internal_note do |order|
            Spree::RichTextHelper.to_plain_text(order.internal_note).presence
          end

          attribute :internal_note_html do |order|
            order.internal_note.presence
          end

          attribute :approver_id do |order|
            order.approver&.prefixed_id
          end

          attribute :canceler_id do |order|
            order.canceler&.prefixed_id
          end

          attribute :created_by_id do |order|
            order.created_by&.prefixed_id
          end

          attribute :customer_id do |order|
            order.customer&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          # Renamed from the store's `discounts` key: on the admin surface that
          # word means the typed money rows (/orders/:id/discounts), so the
          # promotion summaries carry their real name here. The inherited
          # store-keyed declaration is dropped, not shadowed.
          _attributes.delete(:discounts)
          # Fees reach the admin through their own `/orders/:id/fees` endpoint,
          # which is also the write path — embedding them here would ship the
          # same rows twice, through a store serializer.
          _attributes.delete(:fees)
          many :order_promotions, key: :applied_promotions, resource: proc { Spree.api.admin_applied_promotion_serializer }, if: proc { expand?('applied_promotions') }
          many :line_items, key: :items, resource: proc { Spree.api.admin_line_item_serializer }, if: proc { expand?('items') }
          many :fulfillments, resource: proc { Spree.api.admin_fulfillment_serializer }, if: proc { expand?('fulfillments') }
          many :payments, resource: proc { Spree.api.admin_payment_serializer }, if: proc { expand?('payments') }

          one :billing_address, resource: proc { Spree.api.admin_address_serializer }, if: proc { expand?('billing_address') }
          one :shipping_address, resource: proc { Spree.api.admin_address_serializer }, if: proc { expand?('shipping_address') }
          one :gift_card, resource: proc { Spree.api.admin_gift_card_serializer }
          one :cart, resource: proc { Spree.api.admin_cart_serializer }, if: proc { expand?('cart') }
          one :market, resource: proc { Spree.api.admin_market_serializer }
          one :channel, resource: proc { Spree.api.admin_channel_serializer }, if: proc { expand?('channel') }
          one :preferred_stock_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('preferred_stock_location') }

          many :payment_methods, resource: proc { Spree.api.admin_payment_method_serializer }, if: proc { expand?('payment_methods') }

          one :customer,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('customer') }

          one :approver,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('approver') }

          one :canceler,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('canceler') }

          one :created_by,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('created_by') }


          many :returns,
               resource: proc { Spree.api.admin_return_serializer },
               if: proc { expand?('returns') }

          many :exchanges,
               resource: proc { Spree.api.admin_exchange_serializer },
               if: proc { expand?('exchanges') }

          many :claims,
               resource: proc { Spree.api.admin_claim_serializer },
               if: proc { expand?('claims') }
        end
      end
    end
  end
end
