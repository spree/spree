module Spree
  module Api
    module V3
      class CollectionPublicationSerializer < BaseSerializer
        typelize collection_id: :string,
                 channel_id: :string,
                 published_at: [:string, nullable: true],
                 unpublished_at: [:string, nullable: true]

        attributes published_at: :iso8601, unpublished_at: :iso8601

        prefixed_id_attributes :collection, :channel
      end
    end
  end
end
