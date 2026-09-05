module Spree
  module Api
    module V3
      # Store API Product Serializer
      # Customer-facing product data with limited fields
      class ProductSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], description_html: [:string, nullable: true], slug: :string,
                 meta_title: [:string, nullable: true],
                 meta_description: [:string, nullable: true], meta_keywords: [:string, nullable: true],
                 variant_count: :number,
                 default_variant_id: :string,
                 buy_box_variant_id: [:string, nullable: true],
                 thumbnail_url: [:string, nullable: true],
                 available_on: [:string, nullable: true],
                 preorder_ships_at: [:string, nullable: true],
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean, available: :boolean,
                 preorder: :boolean,
                 price: 'Price',
                 original_price: ['Price', nullable: true],
                 tags: [:string, multi: true]

        attributes :name, :slug,
                   :meta_title, :meta_description, :meta_keywords,
                   :variant_count,
                   available_on: :iso8601, preorder_ships_at: :iso8601

        attribute :purchasable do |product|
          product.purchasable?
        end

        # True when this product is currently offered as a pre-order on the
        # requesting channel.
        attribute :preorder do |product|
          product.preorder?
        end

        attribute :in_stock do |product|
          product.in_stock?
        end

        attribute :backorderable do |product|
          product.backorderable?
        end

        attribute :available do |product|
          product.available?
        end

        attribute :description do |product|
          next if product.description.blank?

          Spree::RichTextHelper.to_plain_text(product.description)
        end

        attribute :description_html do |product|
          product.description
        end

        # The product's stable identity for add-to-cart. Deliberately NOT the
        # buy-box winner: that moves with price and stock, and a client that
        # cached or linked this id must not find it pointing at a different
        # row tomorrow. On a single-seller catalog the two coincide anyway.
        attribute :default_variant_id do |product|
          product.default_variant&.prefixed_id
        end

        # The offer a storefront should lead with when several sellers share
        # the listing — the buy-box winner in the request's currency. Nil when
        # nothing wins. Separate from `default_variant_id` so a storefront opts
        # into the marketplace behaviour without the identity field moving
        # under it; storefronts that ignore it lose nothing.
        attribute :buy_box_variant_id do |product|
          product.buy_box_variant(currency: current_currency)&.prefixed_id
        end

        # Main product image URL for listings (cached primary_media)
        attribute :thumbnail_url do |product|
          image_url_for(product.primary_media)
        end

        attribute :tags do |product|
          product.tags.map(&:name) # not pluck as we preload tags
        end

        # Price object - calculated price with price list resolution.
        #
        # Priced off the buy-box winner, not `default_variant_id`. Price is a
        # display fact that already moves with price lists and currency, so it
        # is not an identity — and it must agree with `buy_box_variant_id`: the
        # price a shopper sees is the price of the offer they are shown. On a
        # single-seller catalog winner and default variant are the same row.
        attribute :price do |product|
          price = price_for(featured_variant(product))
          Spree.api.price_serializer.new(price, params: params).to_h if price.present?
        end

        # Original price - base price without price list resolution (for showing strikethrough)
        # Returns null when same as calculated price, only populated when a price list discount is applied
        attribute :original_price do |product|
          variant = featured_variant(product)
          calculated = price_for(variant)
          base = price_in(variant)

          if calculated.present? && base.present? && calculated.id != base.id
            Spree.api.price_serializer.new(base, params: params).to_h
          end
        end

        # Nil on the marketplace's own first-party products. The id is always
        # present so a storefront can group or link by seller without paying
        # for the expand; `?expand=seller` adds the public profile.
        attribute :seller_id do |product|
          product.seller&.prefixed_id
        end

        # Conditional associations
        one :seller,
            resource: proc { Spree.api.seller_serializer },
            if: proc { expand?('seller') }

        one :primary_media,
            resource: proc { Spree.api.media_serializer },
            if: proc { expand?('primary_media') }

        many :gallery_media,
             key: :media,
             resource: proc { Spree.api.media_serializer },
             if: proc { expand?('media') }

        # `listed_variants`, not the raw association: a seller's offer still in
        # review, sent back or taken down is not something a shopper may see
        # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
        many :variants,
             resource: proc { Spree.api.variant_serializer },
             if: proc { expand?('variants') } do |product|
          product.listed_variants
        end

        one :default_variant,
            resource: proc { Spree.api.variant_serializer },
            if: proc { expand?('default_variant') }

        many :option_types,
             resource: proc { Spree.api.option_type_serializer },
             if: proc { expand?('option_types') }

        many :option_values,
             resource: proc { Spree.api.option_value_serializer },
             if: proc { expand?('option_values') }

        many :categories,
             proc { |categories, params|
               store_id = params[:store].id
               categories.select { |c| c.store_id == store_id }
             },
             resource: proc { Spree.api.category_serializer },
             if: proc { expand?('categories') }

        many :storefront_custom_fields,
             key: :custom_fields,
             resource: proc { Spree.api.custom_field_serializer },
             if: proc { expand?('custom_fields') }

        typelize prior_price: ['PriceHistory', nullable: true],
                 seller_id: [:string, nullable: true]

        attribute :prior_price,
                  if: proc { expand?('prior_price') } do |product|
          record = price_in(featured_variant(product))&.prior_price
          Spree.api.price_history_serializer.new(record, params: params).to_h if record
        end
      end
    end
  end
end
