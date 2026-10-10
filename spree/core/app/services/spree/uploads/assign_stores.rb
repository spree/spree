module Spree
  module Uploads
    # Gives every attached file that has no store the store of the record it
    # is attached to (the 6.0 upgrade, `spree:uploads:assign_stores`).
    #
    # Owners with a `store_id` column are handled with one set-based update per
    # attachment type; the rest (a variant's digital file, a seller's
    # submission) ask {Spree::Uploads.store_id_for} record by record. Files
    # attached nowhere keep no store: the daily purge deletes them.
    #
    # Safe to re-run: only files without a store are touched.
    class AssignStores
      prepend Spree::ServiceModule::Base

      BATCH_SIZE = 1_000

      # @return [Spree::ServiceModule::Result] a hash with `assigned`, the
      #   number of files given a store, and `conflicts`, the ids of files
      #   attached to records of more than one store, which are reported and
      #   left for a person to resolve
      def call
        assigned = record_types.sum do |record_type|
          owner_class = record_type.safe_constantize
          next 0 if owner_class.nil?

          if owner_class.column_names.include?('store_id')
            assign_from_store_column(record_type, owner_class)
          else
            assign_record_by_record(record_type)
          end
        end

        success(assigned: assigned, conflicts: conflicting_blob_ids)
      end

      private

      # Renditions and previews take their store from their original file, so
      # they go last, once the originals have one.
      def record_types
        ActiveStorage::Attachment.distinct.pluck(:record_type).
          sort_by { |record_type| [record_type.start_with?('ActiveStorage::') ? 1 : 0, record_type] }
      end

      # Correlated subqueries rather than UPDATE … FROM, which MySQL and SQLite
      # spell differently. Several attachments of one file in different stores
      # pick one; {#conflicting_blob_ids} reports them.
      def assign_from_store_column(record_type, owner_class)
        attachments_table = ActiveStorage::Attachment.table_name
        owners_table = owner_class.table_name
        owner_store = ActiveStorage::Attachment.
                      joins("INNER JOIN #{owners_table} ON #{owners_table}.id = #{attachments_table}.record_id").
                      where(record_type: record_type).
                      where("#{attachments_table}.blob_id = #{ActiveStorage::Blob.table_name}.id").
                      where.not(owners_table => { store_id: nil })

        ActiveStorage::Blob.where(store_id: nil).
          where(id: ActiveStorage::Attachment.where(record_type: record_type).select(:blob_id)).
          where(owner_store.arel.exists).
          update_all(["store_id = (#{owner_store.select("#{owners_table}.store_id").limit(1).to_sql})"])
      end

      # One update per store and batch rather than per file.
      def assign_record_by_record(record_type)
        unassigned = ActiveStorage::Attachment.joins(:blob).
                     where(record_type: record_type, ActiveStorage::Blob.table_name => { store_id: nil })

        unassigned.preload(:record).in_batches(of: BATCH_SIZE).sum do |batch|
          batch.select(&:record).group_by { |attachment| Spree::Uploads.store_id_for(attachment.record) }.sum do |store_id, owned|
            next 0 if store_id.nil?

            ActiveStorage::Blob.where(id: owned.map(&:blob_id), store_id: nil).update_all(store_id: store_id)
          end
        end
      end

      def conflicting_blob_ids
        shared_blob_ids = ActiveStorage::Attachment.group(:blob_id).having('COUNT(*) > 1').pluck(:blob_id)

        shared_blob_ids.each_slice(BATCH_SIZE).flat_map do |blob_ids|
          ActiveStorage::Attachment.where(blob_id: blob_ids).includes(:record).group_by(&:blob_id).filter_map do |blob_id, blob_attachments|
            store_ids = blob_attachments.filter_map { |attachment| attachment.record && Spree::Uploads.store_id_for(attachment.record) }
            blob_id if store_ids.map(&:to_s).uniq.size > 1
          end
        end
      end
    end
  end
end
