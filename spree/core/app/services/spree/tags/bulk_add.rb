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
        names = tag_names.map(&:strip).reject(&:blank?).uniq
        return if names.empty?

        # One read for the names that already exist, then a create only for
        # the ones that do not. `find_or_create_by` per name is a query per
        # tag, which a bulk tagging pays on every name in the payload.
        existing = ActsAsTaggableOn::Tag.where(name: names).index_by(&:name)
        tags = names.map do |name|
          existing[name] || ActsAsTaggableOn::Tag.create_or_find_by(name: name)
        end

        record_class = records.first.class

        taggings_to_upsert = taggings_attributes(tags, records, context: context, record_class: record_class)

        return if taggings_to_upsert.empty?

        ActsAsTaggableOn::Tagging.insert_all(taggings_to_upsert)

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
