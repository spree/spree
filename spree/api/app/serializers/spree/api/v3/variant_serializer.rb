module Spree
  module Api
    module V3
      # Store API Variant Serializer
      # Customer-facing variant data with limited fields
      class VariantSerializer < BaseSerializer
        typelize product_id: :string, sku: [:string, nullable: true],
                 options_text: :string, track_inventory: :boolean, media_count: :number,
                 thumbnail_url: [:string, nullable: true],
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean, preorder: :boolean,
                 preorder_ships_at: [:string, nullable: true],
                 weight: [:number, nullable: true], height: [:number, nullable: true], width: [:number, nullable: true], depth: [:number, nullable: true],
                 price: 'Price',
                 original_price: ['Price', nullable: true],
                 minimum_order_quantity: :number, order_multiple: :number,
                 purchase_unit: :string, units_per_carton: ['number | null'],
                 seller_id: [:string, nullable: true]

        attribute :product_id do |variant|
          variant.product&.prefixed_id
        end

        pricing_access_attribute

        attributes :sku, :options_text, :track_inventory, :media_count

        # Customer-facing "ships by" promise — only while the variant is a
        # pre-order (nil otherwise, even if a stale date lingers on the column).
        attribute :preorder_ships_at do |variant|
          variant.preorder_ships_at&.iso8601 if variant.preorder?
        end

        # Main variant image URL for listings (cached primary_media)
        attribute :thumbnail_url do |variant|
          image_url_for(variant.primary_media)
        end

        attribute :purchasable do |variant|
          variant.purchasable?
        end

        attribute :in_stock do |variant|
          variant.in_stock?
        end

        attribute :backorderable do |variant|
          variant.backorderable?
        end

        attribute :preorder do |variant|
          variant.preorder?
        end

        attribute :weight do |variant|
          variant.weight&.to_f
        end

        attribute :height do |variant|
          variant.height&.to_f
        end

        attribute :width do |variant|
          variant.width&.to_f
        end

        attribute :depth do |variant|
          variant.depth&.to_f
        end

        # The buyer's RESOLVED rules — their catalog terms over the variant's
        # base — so a storefront draws the right stepper without knowing
        # which of the two answered. Always present: an unrestricted variant
        # reads 1 and 1, which is a valid stepper rather than a special case.
        attribute :minimum_order_quantity do |variant|
          quantity_rule_for(variant).minimum
        end

        attribute :order_multiple do |variant|
          quantity_rule_for(variant).multiple
        end

        # What the buyer is quoted in. Stored quantities stay units at every
        # level; this only says how to present them.
        attribute :purchase_unit do |variant|
          variant.purchase_unit.presence || 'unit'
        end

        attribute :units_per_carton do |variant|
          variant.units_per_carton
        end

        # Price object - calculated price with price list resolution
        attribute :price do |variant|
          price = price_for(variant)
          Spree.api.price_serializer.new(price, params: params).to_h if price.present?
        end

        # Original price - base price without price list resolution (for showing strikethrough)
        # Returns null when same as calculated price, only populated when a price list discount is applied
        attribute :original_price do |variant|
          calculated = price_for(variant)
          base = price_in(variant)

          if calculated.present? && base.present? && calculated.id != base.id
            Spree.api.price_serializer.new(base, params: params).to_h
          end
        end

        # Who sells this variant — one answer, resolved on the model, so a
        # storefront never learns whether it came from the product (an owned
        # listing) or the row itself (a master shared by several sellers). Nil
        # is first-party. Shoppers comparing offers on one page group by this,
        # so it is a plain attribute rather than an expand.
        attribute :seller_id do |variant|
          variant.resolved_seller&.prefixed_id
        end

        one :seller,
            resource: proc { Spree.api.seller_serializer },
            if: proc { expand?('seller') } do |variant|
          variant.resolved_seller
        end

        # Conditional associations
        one :primary_media,
            resource: proc { Spree.api.media_serializer },
            if: proc { expand?('primary_media') }

        many :gallery_media,
             key: :media,
             resource: proc { Spree.api.media_serializer },
             if: proc { expand?('media') }

        many :option_values, resource: proc { Spree.api.option_value_serializer }

        many :storefront_custom_fields,
             key: :custom_fields,
             resource: proc { Spree.api.custom_field_serializer },
             if: proc { expand?('custom_fields') }

        typelize prior_price: ['PriceHistory', nullable: true]

        attribute :prior_price,
                  if: proc { expand?('prior_price') } do |variant|
          record = price_in(variant)&.prior_price
          Spree.api.price_history_serializer.new(record, params: params).to_h if record
        end
      end
    end
  end
end
