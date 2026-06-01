module Spree
  module Api
    module V3
      module Admin
        class ProductPublicationSerializer < V3::ProductPublicationSerializer
          typelize store_id: :string,
                   units_sold_count: :number,
                   revenue: [:string, nullable: true]

          attributes :units_sold_count, :revenue,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :store_id do |publication|
            publication.store&.prefixed_id
          end
        end
      end
    end
  end
end
