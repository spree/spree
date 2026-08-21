module Spree
  module Api
    module V3
      module Seller
        class TaxIdentifierSerializer < V3::BaseSerializer
          typelize kind: :string, value: :string,
                   validation_status: [:string, nullable: true],
                   validated_at: [:string, nullable: true]

          attributes :kind, :value, :validation_status, validated_at: :iso8601
        end
      end
    end
  end
end
