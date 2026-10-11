module Spree
  module Api
    module V3
      # Request shapes several endpoints accept, published once per API so
      # each SDK has one type for them. See Spree::Api::V3::RequestSchema.
      module RequestShapes
        PRICE = RequestSchema.shape('PriceParams') do
          string :currency, required: true, example: 'USD'
          decimal :amount, required: true, example: '29.99',
                           description: 'A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse localized input.'
          decimal :compare_at_amount, nullable: true, example: '39.99'
        end

        VARIANT_OPTION = RequestSchema.shape('VariantOptionParams') do
          string :name, required: true, example: 'size'
          string :value, required: true, example: 'Small'
        end

        STOCK_LEVEL = RequestSchema.shape('StockLevelParams') do
          id :id
          id :stock_location_id, required: true, description: 'The location holding the stock (`sloc_...`).'
          integer :count_on_hand, required: true,
                                  description: 'Units physically at the location, not units available to sell: stock promised to placed orders counts until it ships. Sent as the count the shelf should end at; the API records the difference as an adjustment in the stock history.'
          boolean :backorderable, description: 'Whether this location sells the variant beyond what it holds.'
        end

        # A variant's own attributes, shared by the variant endpoints and the
        # variants nested in a product payload. Not published on its own: each
        # endpoint includes these fields into its own type.
        VARIANT_ATTRIBUTES = RequestSchema.new do
          string :sku, :barcode
          decimal :cost_price, nullable: true
          string :cost_currency
          number :weight, :height, :width, :depth, nullable: true
          string :weight_unit, enum: Spree::Variant::WEIGHT_UNITS
          string :dimensions_unit, enum: Spree::Variant::DIMENSION_UNITS
          string :hs_code, :country_of_origin, :customs_description
          integer :minimum_order_quantity, :order_multiple, nullable: true
          string :purchase_unit
          integer :units_per_carton, nullable: true, description: 'How many units fill one carton.'
          id :carton_package_type_id, nullable: true,
                                      description: 'The carton this variant is packed into: a package type of kind `carton`. Its dimensions are shared by every product packed the same way, so a corrected carton size fixes all of them at once.'
          number :carton_weight, nullable: true, description: "What one packed carton weighs, in the variant's weight unit."
          integer :cartons_per_pallet, nullable: true, description: 'How many cartons stack on one pallet.'
          id :seller_id
          id :delivery_profile_id, nullable: true
          boolean :track_inventory
          boolean :preorderable,
                  description: "Sell this variant before it's in stock. Adds the pre-order label and ships-by promise; the cap comes from `backorder_limit`, an incoming stock count, or backorder."
          datetime :preorder_ships_at, nullable: true,
                                       description: 'The "ships by" date shown to customers while the variant is a pre-order. Once it passes, the variant is no longer a pre-order. Null clears it.'
          integer :backorder_limit, nullable: true,
                                    description: 'Maximum units sellable beyond available stock, capping backorders and pre-orders. Null is unlimited.'
          id :tax_category_id
          integer :position
          object :prices, array: true, shape: PRICE, description: 'Per-currency prices. Upserted by currency.'
          object :stock_levels, array: true, shape: STOCK_LEVEL,
                                description: 'Stock per location. Upserted by location; omitted locations are removed.'
        end

        CUSTOM_FIELD_VALUE = RequestSchema.shape('CustomFieldValueParams') do
          id :id
          id :custom_field_definition_id
          any :value, description: 'A scalar for text, number and boolean fields; a list or a hash for JSON fields.'
        end

        PRICE_LIST_RULE = RequestSchema.shape('PriceListRuleParams') do
          id :id, nullable: true, description: 'Present for existing rules. Omit to create a new one.'
          string :type, required: true, example: 'volume_rule',
                        description: 'Wire shorthand for the rule kind, from the price rule types endpoint.'
          object :preferences, description: "The rule kind's settings, keyed by preference name."
        end

        PRICE_ADJUSTMENT_TIER = RequestSchema.shape('PriceAdjustmentTierParams') do
          integer :min_quantity, required: true, example: 10,
                                 description: "Above 1; quantity 1 is the list's own `price_adjustment_percentage`."
          decimal :percentage, required: true, example: '-10.0', description: 'Signed: negative discounts, positive marks up.'
        end

        # The least a whole order must come to under a catalog, in one currency.
        CATALOG_ORDER_MINIMUM = RequestSchema.shape('CatalogOrderMinimumParams') do
          string :currency, example: 'USD', description: 'ISO 4217 code. Required on create; one minimum per currency.'
          decimal :amount, example: '500.00'
        end

        PRICE_LIST_PRICE =RequestSchema.shape('PriceListPriceOverrideParams') do
          id :id, description: 'Updates this price row. Without it, the row upserts on `(variant_id, currency, min_quantity)`.'
          id :variant_id, example: 'variant_xY9'
          string :currency, example: 'USD'
          integer :min_quantity, description: "The rung of the variant's ladder. Omit for the bottom rung."
          decimal :amount, :compare_at_amount, nullable: true, example: '19.99'
        end

        # The writable attributes of an address (Spree::Api::V3::AddressParams).
        # Not published on its own: each endpoint includes these fields into
        # its own type, beside what it adds (default flags, a label).
        ADDRESS_FIELDS = RequestSchema.new do
          string(*(AddressParams::ADDRESS_KEYS - %i[country_code state_code]))
          string :country_code, description: 'ISO 3166-1 alpha-2 code, such as `US`.'
          string :state_code, description: 'The state or province abbreviation, such as `NY`.'
        end

        # An address as a shopper writes it on the Store API: on a cart and in
        # their own address book. Not published on its own, like ADDRESS_FIELDS.
        STORE_ADDRESS_FIELDS = RequestSchema.new do
          string :first_name, :last_name, :company, :address1, :address2, :city, :postal_code, :phone
          string :country_code, example: 'US', description: 'ISO 3166-1 alpha-2 country code, such as `US` or `DE`.'
          string :state_code, example: 'NY', description: 'ISO 3166-2 subdivision code without the country prefix, such as `CA` or `NY`.'
          string :state_name, description: 'The state name, for countries without predefined states.'
          string :country_iso, description: 'Deprecated: use `country_code`. Accepted until 6.1.'
          string :state_abbr, description: 'Deprecated: use `state_code`. Accepted until 6.1.'
        end

        # A tax registration as a shopper writes it, on their profile or on a
        # cart. Each declares it as `TaxIdentifierParams` with only these fields.
        # Registry-driven, so a plain string: any kind is stored, and one with a
        # validator in Spree.tax_identifier_validators is checked by it.
        TAX_IDENTIFIER_KIND = 'The registration the number belongs to, such as `eu_vat` or `gb_vat`. ' \
                              'Any kind is accepted; one with a registered validator is checked by it. ' \
                              'Built-in: `eu_vat`. Extensions may register more.'.freeze

        TAX_IDENTIFIER_FIELDS = RequestSchema.new do
          string :kind, required: true, example: 'eu_vat', description: TAX_IDENTIFIER_KIND
          string :value, required: true, example: 'DE123456789'
        end

        # The keys of a promotion rule or action beyond `type`, shared by the
        # nested promotion rule and action endpoints and by the `rules` and
        # `actions` written with a promotion. Kind-specific keys are read
        # per kind from its `additional_permitted_attributes`, so they are
        # documented here and left out of the permit list.
        PROMOTION_RULE_FIELDS = RequestSchema.new do
          object :preferences, description: "Values for the rule kind's settings schema, from `GET /promotion_rules/types`."
          id :product_ids, array: true, permit: false, description: 'For the `product` rule.'
          id :category_ids, array: true, permit: false, description: 'For the `category` rule.'
          id :customer_ids, array: true, permit: false, description: 'For the `user` rule: the customers who qualify.'
        end

        PROMOTION_ACTION_CALCULATOR = RequestSchema.shape('PromotionActionCalculatorParams') do
          string :type, example: 'flat_percent_item_total',
                        description: 'The calculator kind, from `GET /promotion_actions/calculators`. Changing it swaps the calculator.'
          object :preferences, description: "Values for the calculator's settings, such as `amount` or `flat_percent`."
        end

        PROMOTION_ACTION_LINE_ITEM = RequestSchema.shape('PromotionActionLineItemParams') do
          id :variant_id, required: true
          integer :quantity, required: true
        end

        PROMOTION_ACTION_FIELDS = RequestSchema.new do
          object :preferences, description: "Values for the action kind's settings schema, from `GET /promotion_actions/types`."
          object :calculator, shape: PROMOTION_ACTION_CALCULATOR, permit: false, description: 'For adjustment actions.'
          object :line_items, array: true, shape: PROMOTION_ACTION_LINE_ITEM, permit: false,
                              description: 'For `create_line_items`: the variants to add and their quantities. Variants left out are removed.'
        end

        # The body of the shared bulk tag actions (Spree::Api::V3::BulkOperations).
        # Each controller declares it as `BulkTagsParams` with only these fields,
        # so the published component is the same wherever it is used.
        BULK_TAGS = RequestSchema.new do
          id :ids, array: true, required: true,
                   description: 'The records to change. Records the caller cannot update are skipped; an empty list changes nothing.'
          string :tags, array: true, required: true, example: %w[vip wholesale]
        end

        # The language every email template endpoint takes. Read from the raw
        # params (Admin::EmailTemplateLookup), so never permitted. Not
        # published on its own.
        EMAIL_TEMPLATE_LANGUAGE = RequestSchema.new do
          string :language, permit: false, example: 'any',
                            description: 'A language code, or `any` (the default) for the version every language uses.'
        end

        # What the email template preview and test email endpoints render.
        # Not published on its own: both declare it as `EmailTemplatePreviewParams`.
        EMAIL_TEMPLATE_PREVIEW = RequestSchema.new do
          include_fields EMAIL_TEMPLATE_LANGUAGE
          string :subject, nullable: true, example: 'Your order {{ order.number }} is confirmed',
                           description: 'An unsaved subject, in place of the current one.'
          string :body, example: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
                        description: 'An unsaved body, in place of the current one.'
          id :record_id, example: 'or_m3Rp9wXz',
                         description: "The record to build sample data from; the store's latest matching record otherwise."
          string :email_key, permit: false, example: 'spree.order_mailer.confirm_email',
                             description: 'For the layout or a partial, the email to show it in.'
          object :branding, permit: false,
                            description: "Unsaved colors and font to preview, named like the store's `email_*` settings." do
            string(*Spree::Emails::Branding::COLORS, nullable: true)
            string :font, nullable: true, enum: Spree::Emails::Branding::FONTS.keys
          end
        end
      end
    end
  end
end
