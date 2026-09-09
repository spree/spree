module Spree
  module Api
    module V3
      module Seller
        # What a seller packs their goods into: their own boxes, cartons and
        # pallets, and the marketplace's shared packaging they may also use.
        #
        # Declared on `BaseSerializer` rather than on a store twin because
        # there is none — a shopper never picks their packaging, so package
        # types exist on the back-office surfaces only.
        #
        # `editable` is what the panel renders a marketplace row read-only by,
        # mirroring the seller's delivery method serializer: a seller sees the
        # operator's cartons so they know what they can pack into, and the API
        # refuses to write them (docs/plans/6.0-seller-package-types.md).
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
                   editable: :boolean,
                   metadata: ['Record<string, unknown> | null']

          attributes :name, :kind, :length, :width, :height, :weight, :max_weight,
                     :default, :metadata

          attributes created_at: :iso8601, updated_at: :iso8601

          # Both units read through their fallbacks, so a row that never set
          # one still tells the seller what its numbers mean.
          attribute :dimensions_unit, &:dimensions_unit
          attribute :weight_unit, &:weight_unit

          attribute :volume, &:volume

          # False for a marketplace row: listed so the seller knows what they
          # can pack into, and not theirs to change.
          attribute :editable do |package_type|
            package_type.seller_id.present?
          end
        end
      end
    end
  end
end
