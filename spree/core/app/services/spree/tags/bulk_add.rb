module Spree
  module Tags
    class BulkAdd
      prepend Spree::ServiceModule::Base

      # Adds the given tags to the given records.
      #
      # @param tag_names [Array<String>] eg. ['tag1', 'tag2']
      # @param records [Array<Spree::Taggable>] eg. Spree::Product, Spree::User
      # @param context [String] default: 'tags'
      # @return [Spree::ServiceModule::Base::Result]
      def call(tag_names: [], records: [], context: 'tags')
        tags = tag_names.map do |tag_name|
          ActsAsTaggableOn::Tag.find_or_create_by(name: tag_name.strip)
        end

        record_class = records.first.class
        record_ids = records.pluck(:id)
        tag_ids = tags.map(&:id)

        taggings_scope = taggings_scope_for(record_ids, record_class, context, tag_ids)

        existing = taggings_scope.pluck(:id, :taggable_id, :tag_id)
        existing_pairs = existing.map { |_, taggable_id, tag_id| [taggable_id, tag_id] }.to_set

        new_taggings = taggings_attributes(tags, records, context: context, record_class: record_class).reject do |attrs|
          existing_pairs.include?([attrs[:taggable_id], attrs[:tag_id]])
        end

        record_class.where(id: record_ids).touch_all

        return if new_taggings.empty?

        ActsAsTaggableOn::Tagging.insert_all(new_taggings)

        new_tagging_ids = taggings_scope.where.not(id: existing.map(&:first)).pluck(:id)

        Spree::Events.publish('tagging.bulk_created', { tagging_ids: new_tagging_ids }) if new_tagging_ids.any?
      end

      private

      def taggings_scope_for(record_ids, record_class, context, tag_ids)
        ActsAsTaggableOn::Tagging.where(
          taggable_id: record_ids,
          taggable_type: record_class.to_s,
          context: context,
          tag_id: tag_ids
        )
      end

      def taggings_attributes(tags, records, context:, record_class:)
        records.pluck(:id).map do |record_id|
          tags.map do |tag|
            {
              taggable_id: record_id,
              taggable_type: record_class.to_s,
              context: context,
              tag_id: tag.id
            }
          end
        end.flatten.compact
      end
    end
  end
end
