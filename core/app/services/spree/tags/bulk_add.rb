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
          Spree::Tag.find_or_create_with_like_by_name(tag_name.strip)
        end

        record_class = records.first.class

        taggings_to_upsert = taggings_attributes(tags, records, context: context, record_class: record_class)

        return if taggings_to_upsert.empty?

        Spree::Tagging.insert_all(taggings_to_upsert)

        record_class.where(id: records.pluck(:id)).touch_all
      end

      private

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
