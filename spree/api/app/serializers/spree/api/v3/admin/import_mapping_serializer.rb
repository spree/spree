module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::ImportMapping}. The
        # `complete_mapping` endpoint accepts exactly these attribute names
        # back (read/write symmetry).
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
