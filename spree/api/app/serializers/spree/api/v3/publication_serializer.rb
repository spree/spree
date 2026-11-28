module Spree
  module Api
    module V3
      # A record's publication on one sales channel. The product, category and
      # collection publication serializers add the id of what they publish.
      class PublicationSerializer < BaseSerializer
        typelize channel_id: :string,
                 published_at: [:string, nullable: true],
                 unpublished_at: [:string, nullable: true]

        attributes published_at: :iso8601, unpublished_at: :iso8601

        prefixed_id_attributes :channel
      end
    end
  end
end
