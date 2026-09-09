module Spree
  module Api
    module V3
      module Admin
        # One product's contribution to the rollup: how many units, the
        # cartons they fill and how those were measured.
        #
        # Back-office only. A buyer is told what their shipment costs and how
        # big it is; which SKU accounts for which part of it is the
        # warehouse's business.
        class FreightSummaryLineSerializer < BaseSerializer
          # A value object, not a record — it has no id of its own.
          _attributes.delete(:id)

          typelize variant_id: [:string, nullable: true],
                   sku: [:string, nullable: true],
                   name: [:string, nullable: true],
                   units: :number,
                   cartons: ['number | null'],
                   pallets: ['number | null'],
                   units_per_carton: ['number | null'],
                   cartons_per_pallet: ['number | null'],
                   weight_per_carton: [:string, nullable: true],
                   volume: :string,
                   weight: :string,
                   complete: :boolean

          attributes :variant_id, :sku, :name, :units, :cartons, :pallets,
                     :units_per_carton, :cartons_per_pallet, :complete

          attribute :weight_per_carton do |line|
            decimal_string(line.weight_per_carton)
          end

          attribute :volume do |line|
            decimal_string(line.volume)
          end

          attribute :weight do |line|
            decimal_string(line.weight)
          end
        end
      end
    end
  end
end
