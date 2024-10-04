module Spree
  module Tags
    class BulkRemove
      prepend Spree::ServiceModule::Base

      def call(tag_names: [], records: [], context: 'tags')
        tag_ids = ActsAsTaggableOn::Tag.where(name: tag_names.map(&:strip)).pluck(:id)

        return if tag_ids.empty?

        record_class = records.first.class

        ActsAsTaggableOn::Tagging.where(
          taggable_id: records.pluck(:id),
          taggable_type: record_class.to_s,
          context: context,
          tag_id: tag_ids
        ).delete_all

        record_class.where(id: records.pluck(:id)).touch_all
      end
    end
  end
end
