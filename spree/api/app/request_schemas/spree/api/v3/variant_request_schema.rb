module Spree
  module Api
    module V3
      # A variant's own attributes, the ones a seller may write too. Each API
      # publishes its own `VariantParams` from a subclass, which the variant
      # endpoints and the variants nested in a product payload both extend.
      class VariantRequestSchema < Spree::Api::V3::RequestSchema
        attribute :sku, :string
        attribute :barcode, :string
        attribute :cost_price, :decimal, nullable: true
        attribute :cost_currency, :currency
        attribute :weight, :number, nullable: true
        attribute :height, :number, nullable: true
        attribute :width, :number, nullable: true
        attribute :depth, :number, nullable: true
        attribute :weight_unit, :weight_unit, nullable: true, description: "Null falls back to the store's weight unit."
        attribute :dimensions_unit, :dimension_unit, nullable: true, description: "Null falls back to the store's unit system."
        attribute :hs_code, :string
        attribute :customs_description, :string
        attribute :country_of_origin, :country
        attribute :minimum_order_quantity, :integer, nullable: true
        attribute :order_multiple, :integer, nullable: true
        attribute :purchase_unit, :string, nullable: true, choices: Spree::Variant::PURCHASE_UNITS
        attribute :units_per_carton, :integer, nullable: true, description: 'How many units fill one carton.'
        attribute :carton_package_type_id, :id,
          nullable: true,
          description: 'The carton this variant is packed into: a package type of kind `carton`. Its dimensions are shared by every product packed the same way, so a corrected carton size fixes all of them at once.'
        attribute :carton_weight, :number,
          nullable: true,
          description: "What one packed carton weighs, in the variant's weight unit."
        attribute :cartons_per_pallet, :integer, nullable: true, description: 'How many cartons stack on one pallet.'
        attribute :track_inventory, :boolean
        attribute :preorderable, :boolean,
          description: "Sell this variant before it's in stock. Adds the pre-order label and ships-by promise; the cap comes from `backorder_limit`, an incoming stock count, or backorder."
        attribute :preorder_ships_at, :datetime,
          nullable: true,
          description: 'The "ships by" date shown to customers while the variant is a pre-order. Once it passes, the variant is no longer a pre-order. Null clears it.'
        attribute :backorder_limit, :integer,
          nullable: true,
          description: 'Maximum units sellable beyond available stock, capping backorders and pre-orders. Null is unlimited.'
        attribute :position, :integer
        attribute :options, :array, of: Spree::Api::V3::VariantOptionRequestSchema,
          description: 'One pair per option type the variant takes part in (size, color). Option types and values are created when missing.'
      end
    end
  end
end
