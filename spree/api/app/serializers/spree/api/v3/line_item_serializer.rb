module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        typelize variant_id: :string, quantity: :number,
                 currency: [:string, { enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode' }],
                 name: :string, slug: :string, options_text: :string,
                 compare_at_amount: [:string, { nullable: true, comment: 'The compare-at price times quantity, or null when the variant has none.' }],
                 thumbnail_url: [:string, { nullable: true }], preorder: :boolean,
                 preorder_ships_at: [:string, { nullable: true }], seller_id: [:string, { nullable: true }],
                 gift_card: [:boolean, { comment: 'True when the line buys a gift card, issued when the order is paid.' }],
                 recipient: { nullable: true }

        prefixed_id_attributes :variant

        # Which seller this line was bought from, snapshotted when it was
        # added — nil is the operator's own first-party item. Always present
        # so a storefront can group a multi-seller cart without paying for the
        # expand; `?expand=seller` adds the public profile.
        prefixed_id_attributes :seller

        # True when the line item's variant is currently a pre-order, so the
        # cart/checkout can flag it as shipping later.
        attribute :preorder do |line_item|
          line_item.variant&.preorder? || false
        end

        # The variant's "ships by" promise while it's a pre-order.
        attribute :preorder_ships_at do |line_item|
          line_item.variant&.preorder_ships_at&.iso8601 if line_item.variant&.preorder?
        end

        attributes :quantity, :currency, :name, :slug, :options_text

        attribute :gift_card, &:gift_card?

        # Nulled for gated (prices_hidden) guests so the cart's line items can't
        # leak the prices that product/variant serializers already withhold.
        money_attributes :price, :display_price, unit_price: true, descriptions: { price: 'The price of one unit.' }
        money_attributes :total, :display_total,
                         :adjustment_total, :display_adjustment_total,
                         :additional_tax_total, :display_additional_tax_total,
                         :included_tax_total, :display_included_tax_total,
                         :discount_total, :display_discount_total,
                         :pre_tax_amount, :display_pre_tax_amount,
                         :discounted_amount, :display_discounted_amount,
                         :display_compare_at_amount,
                         descriptions: {
                           total: 'What this line costs: price times quantity, with its discounts, fees and added tax.',
                           adjustment_total: "This line's discounts, fees and added tax together.",
                           additional_tax_total: 'Tax added on top of the price.',
                           included_tax_total: 'Tax already included in the price.',
                           discount_total: 'What promotions take off this line, as a negative amount.',
                           pre_tax_amount: 'This line after discounts, without tax.',
                           discounted_amount: 'Price times quantity, after discounts.'
                         }

        # Return compare_at_amount as string, nil if zero
        attribute :compare_at_amount do |line_item|
          next nil if params[:hide_prices]

          amount = line_item.compare_at_amount
          if amount.present? && amount.positive?
            Spree::Money::Rounding.format(amount, line_item.currency,
                                          unit_price: true)
          end
        end

        # Thumbnail URL for line item (variant thumbnail or product thumbnail)
        attribute :thumbnail_url do |line_item|
          image_url_for(line_item.thumbnail)
        end

        one :seller,
            resource: proc { Spree.api.seller_serializer },
            if: proc { expand?('seller') }

        many :option_values, resource: proc { Spree.api.option_value_serializer }
        # Download links carry a bearer token; only the buyer gets them.
        many :digital_links, resource: proc { Spree.api.digital_link_serializer }, if: proc {
          !params[:hide_credentials]
        }
        # Tax hangs off its adjustable, never off the cart or order: the
        # exactly-one-adjustable rule makes the nested view complete, and the
        # owner already carries the tax totals.
        many :tax_lines, resource: proc { Spree.api.tax_line_serializer }, if: proc { expand?('tax_lines') }

        # Who a gift card line is for; null on every other line, and on a gift
        # card line whose cards go to the buyer. Read only for gift card
        # lines, so an ordinary cart pays no query.
        one :gift_card_recipient, key: :recipient, resource: proc { Spree.api.gift_card_recipient_serializer },
                                  source: proc { gift_card_recipient if gift_card? }

        # The cards a paid order issued for this line. Masked: the code is
        # the recipient's to spend, and only their email carries it.
        many :gift_cards, resource: proc { Spree.api.gift_card_serializer },
                          params: { hide_credentials: true },
                          source: proc { gift_card? ? gift_cards : [] },
                          if: proc { |line_item| line_item.order_id.present? }

        expandable_custom_fields
      end
    end
  end
end
