module Spree
  module Tags
    class BulkRemove
      prepend Spree::ServiceModule::Base

      def call(tag_names: [], records: [], context: 'tags')
        tag_ids = ActsAsTaggableOn::Tag.where(name: tag_names.map(&:strip)).pluck(:id)

        return if tag_ids.empty?

        record_class = records.first.class
        record_ids = records.pluck(:id)

        taggings_scope = ActsAsTaggableOn::Tagging.where(
          taggable_id: record_ids,
          taggable_type: record_class.to_s,
          context: context,
          tag_id: tag_ids
        )

        taggings_data = taggings_scope.select(:id, :tag_id, :taggable_id, :taggable_type, :context).map do |t|
          { id: t.id, tag_id: t.tag_id, taggable_id: t.taggable_id, taggable_type: t.taggable_type, context: t.context }
        end

        taggings_scope.delete_all

        record_class.where(id: record_ids).touch_all

        Spree::Events.publish('tagging.bulk_removed', { taggings: taggings_data }) if taggings_data.any?
      end
    end
  end
end
