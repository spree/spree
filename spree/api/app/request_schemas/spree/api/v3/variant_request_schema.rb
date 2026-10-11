module Spree
  module Api
    module V3
      # A variant's own attributes, shared by the variant endpoints and the
      # variants nested in a product payload. Not published on its own: each
      # endpoint includes these fields into its own type.
      class VariantRequestSchema < Spree::Api::V3::RequestSchema
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
        object :prices, array: true, shape: Spree::Api::V3::PriceRequestSchema, description: 'Per-currency prices. Upserted by currency.'
        object :stock_levels, array: true, shape: Spree::Api::V3::StockLevelRequestSchema,
                              description: 'Stock per location. Upserted by location; omitted locations are removed.'
      end
    end
  end
end
