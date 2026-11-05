module Spree
  module Collections
    # Creates a collection and publishes it. Without a `publications` set in
    # the attributes the collection goes live on every active channel of its
    # store, so API clients that create collections keep getting live ones
    # (docs/plans/6.1-collections-merchandising.md).
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :collection

      # @param store [Spree::Store]
      # @param attributes [Hash] may carry `publications`
      # @return [Spree::ServiceModule::Result] value is the collection
      def perform(store:, attributes: {})
        super

        step :build_collection
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_collection
          step :publish_on_active_channels
          run_hooks :after_create
        end

        @published_channels&.each do |channel|
          collection.publish_event('collection.published', nil, { channel_id: channel.prefixed_id })
        end

        success(collection)
      end

      private

      def build_collection
        @collection = store.collections.new(attributes.to_h)
      end

      def save_collection
        failure(collection) unless collection.save
      end

      def publish_on_active_channels
        return if collection.publications_assigned?

        @published_channels = store.channels.active.to_a
        Spree::Channel.where(id: @published_channels.map(&:id)).add_collections(collection.id)
      end
    end
  end
end
