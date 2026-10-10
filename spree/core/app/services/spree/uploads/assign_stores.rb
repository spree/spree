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

      def blobs
        ActiveStorage::Blob
      end

      def attachments
        ActiveStorage::Attachment
      end

      def record_types
        attachments.distinct.pluck(:record_type)
      end

      def unassigned_attachments(record_type)
        attachments.joins(:blob).where(record_type: record_type, blobs.table_name => { store_id: nil })
      end

      # Correlated subqueries rather than UPDATE … FROM, which MySQL and SQLite
      # spell differently. Several attachments of one file in different stores
      # pick one; {#conflicting_blob_ids} reports them.
      def assign_from_store_column(record_type, owner_class)
        blobs_table = blobs.table_name
        owners_table = owner_class.table_name
        owner_store = attachments.joins("INNER JOIN #{owners_table} ON #{owners_table}.id = #{attachments.table_name}.record_id").
                      where(record_type: record_type).
                      where("#{attachments.table_name}.blob_id = #{blobs_table}.id").
                      where.not(owners_table => { store_id: nil })

        blobs.where(store_id: nil).
          where(owner_store.arel.exists).
          update_all(["store_id = (#{owner_store.select("#{owners_table}.store_id").limit(1).to_sql})"])
      end

      def assign_record_by_record(record_type)
        count = 0

        unassigned_attachments(record_type).preload(:record, :blob).find_each(batch_size: BATCH_SIZE) do |attachment|
          next if attachment.record.nil? || attachment.blob.store_id.present?

          store_id = Spree::Uploads.store_id_for(attachment.record)
          next if store_id.nil?

          count += blobs.where(id: attachment.blob_id, store_id: nil).update_all(store_id: store_id)
        end

        count
      end

      def conflicting_blob_ids
        shared_blob_ids = attachments.group(:blob_id).having('COUNT(*) > 1').pluck(:blob_id)

        shared_blob_ids.each_slice(BATCH_SIZE).flat_map do |blob_ids|
          attachments.where(blob_id: blob_ids).includes(:record).group_by(&:blob_id).filter_map do |blob_id, blob_attachments|
            store_ids = blob_attachments.filter_map { |attachment| attachment.record && Spree::Uploads.store_id_for(attachment.record) }
            blob_id if store_ids.map(&:to_s).uniq.size > 1
          end
        end
      end
    end
  end
end
