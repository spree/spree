module Spree
  module Api
    module V3
      module Admin
        # One channel of a category's or collection's `publications` set.
        class PublicationRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PublicationParams'

          attribute :channel_id, :id, example: 'ch_abc123'
          attribute :published_at, :datetime, nullable: true, description: 'When the record goes live on the channel. Null means immediately.'
          attribute :unpublished_at, :datetime, nullable: true, description: 'When the record comes down from the channel. Null means never.'
        end
      end
    end
  end
end
