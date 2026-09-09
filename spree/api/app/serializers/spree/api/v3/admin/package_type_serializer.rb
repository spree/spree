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
                   length: [:string, nullable: true],
                   width: [:string, nullable: true],
                   height: [:string, nullable: true],
                   dimensions_unit: :string,
                   weight: [:string, nullable: true],
                   max_weight: [:string, nullable: true],
                   weight_unit: :string,
                   volume: [:string, nullable: true],
                   default: :boolean,
                   seller_id: [:string, nullable: true],
                   seller_name: [:string, nullable: true],
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

          # Whose packaging this is: a seller's own, or (null) the
          # marketplace's shared vocabulary
          # (docs/plans/6.0-seller-package-types.md).
          attribute :seller_id do |package_type|
            package_type.seller&.prefixed_id
          end

          attribute :seller_name do |package_type|
            package_type.seller&.name
          end
        end
      end
    end
  end
end
