module Spree
  module Api
    module V3
      module Admin
        # A store's packaging: the box it ships parcels in, and the cartons,
        # pallets and containers a wholesale order leaves on. Back-office
        # only — a shopper never picks their packaging.
        class PackageTypeSerializer < V3::BaseSerializer
          typelize name: :string,
                   kind: :string,
                   length: [:number, nullable: true],
                   width: [:number, nullable: true],
                   height: [:number, nullable: true],
                   dimensions_unit: :string,
                   weight: [:number, nullable: true],
                   max_weight: [:number, nullable: true],
                   weight_unit: :string,
                   volume: [:number, nullable: true],
                   default: :boolean,
                   metadata: ['Record<string, unknown> | null']

          attributes :name, :kind, :length, :width, :height, :weight, :max_weight,
                     :default, :metadata

          attributes created_at: :iso8601, updated_at: :iso8601

          # Both units read through their fallbacks, so a row that never set
          # one still tells the merchant what its numbers mean.
          attribute :dimensions_unit, &:dimensions_unit
          attribute :weight_unit, &:weight_unit

          # Cubic meters, so a merchant configuring volume tiers can read the
          # figure their rules are compared against. Null until every side is
          # measured.
          attribute :volume, &:volume
        end
      end
    end
  end
end
