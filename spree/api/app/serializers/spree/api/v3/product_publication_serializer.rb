module Spree
  module Api
    module V3
      class ProductPublicationSerializer < BaseSerializer
        typelize product_id: :string,
                 channel_id: :string,
                 published_at: [:string, nullable: true],
                 unpublished_at: [:string, nullable: true]

        attributes published_at: :iso8601, unpublished_at: :iso8601

        attribute :product_id do |publication|
          publication.product&.prefixed_id
        end

        attribute :channel_id do |publication|
          publication.channel&.prefixed_id
        end
      end
    end
  end
end
