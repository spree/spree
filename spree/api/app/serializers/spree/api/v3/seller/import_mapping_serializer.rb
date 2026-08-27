module Spree
  module Api
    module V3
      module Seller
        # How one schema field of a seller's import maps onto a column of
        # their CSV. The `complete_mapping` endpoint accepts exactly these
        # attribute names back (read/write symmetry).
        class ImportMappingSerializer < V3::BaseSerializer
          typelize schema_field: :string,
                   file_column: [:string, nullable: true],
                   required: :boolean

          attributes :schema_field, :file_column

          attribute :required, &:required?
        end
      end
    end
  end
end
