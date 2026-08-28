module Spree
  module Api
    module V3
      module Admin
        class CatalogAssignmentSerializer < V3::BaseSerializer
          typelize catalog_id: :string, assignable_type: :string, assignable_id: :string,
                   assignable_name: [:string, nullable: true]

          attributes created_at: :iso8601

          attribute :catalog_id do |assignment|
            assignment.catalog.prefixed_id
          end

          # The client-facing type vocabulary: 'company', 'customer_group' —
          # never Ruby class names.
          attribute :assignable_type do |assignment|
            assignment.assignable_type.demodulize.underscore
          end

          attribute :assignable_id do |assignment|
            assignment.assignable&.prefixed_id
          end

          attribute :assignable_name do |assignment|
            assignment.assignable.try(:name)
          end
        end
      end
    end
  end
end
