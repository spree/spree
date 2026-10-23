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

        taggings_to_upsert = taggings_attributes(tags, records, context: context, record_class: record_class)

        return if taggings_to_upsert.empty?

        ActsAsTaggableOn::Tagging.insert_all(taggings_to_upsert)

        record_class.where(id: records.pluck(:id)).touch_all
      end

      private

      # Mirrors the gem's own tagging save, which stores the taggable's tenant
      # (its `store_id` for store-owned records) as a string on each tagging.
      def taggings_attributes(tags, records, context:, record_class:)
        records.flat_map do |record|
          tags.map do |tag|
            {
              taggable_id: record.id,
              taggable_type: record_class.to_s,
              context: context,
              tag_id: tag.id,
              tenant: record.taggable_tenant&.to_s
            }
          end
        end
      end
    end
  end
end
