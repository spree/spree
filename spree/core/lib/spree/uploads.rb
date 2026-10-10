module Spree
  # Store ownership of uploaded files (docs/plans/6.0-uploads-and-file-ownership.md).
  #
  # Every `ActiveStorage::Blob` records the store that owns it, and attaching a
  # blob to a record of another store is reported. Spree 6.0 only logs; 6.1
  # refuses, so one release of logs finds every path that still creates blobs
  # without a store.
  module Uploads
    # How long an upload reference (`signed_id`) stays attachable.
    SIGNED_ID_EXPIRY = 1.day

    # Mints an expiring upload reference for +blob+.
    #
    # @param blob [ActiveStorage::Blob]
    # @return [String] an opaque reference clients pass back unchanged
    def self.signed_id_for(blob)
      blob.signed_id(expires_in: SIGNED_ID_EXPIRY)
    end

    # The store owning +record+, or nil for records that belong to no store
    # (admin users, customers).
    #
    # @param record [ActiveRecord::Base]
    # @return [Integer, String, nil]
    def self.store_id_for(record)
      return record.id if record.is_a?(Spree::Store)
      # A processed rendition belongs to whoever owns its original.
      return record.blob&.store_id if record.is_a?(ActiveStorage::VariantRecord)
      return record.store_id if record.has_attribute?(:store_id)

      record.try(:store)&.id
    end

    module BlobStoreOwnership
      extend ActiveSupport::Concern

      included do
        before_create :assign_current_store
      end

      private

      # Reads the store a request or job declared, never the default-store
      # fallback: guessing the default would hide exactly the creation paths
      # the 6.0 logs are meant to find.
      def assign_current_store
        return unless has_attribute?(:store_id)

        self.store_id ||= Spree::Current.attributes[:store]&.id
      end
    end

    module AttachmentStoreCheck
      extend ActiveSupport::Concern

      included do
        after_create :check_blob_store
      end

      private

      def check_blob_store
        return unless blob&.has_attribute?(:store_id)
        return if record.nil?

        owner_store_id = Spree::Uploads.store_id_for(record)
        return if owner_store_id.nil?

        if blob.store_id.nil?
          # A file Spree just made from bytes it holds (an export, a purchased
          # label) is created in the same call that attaches it, so it simply
          # takes its owner's store. Only an existing file without one is
          # worth reporting.
          return blob.update_column(:store_id, owner_store_id) if blob.previously_new_record?

          report_store_mismatch('has no store', owner_store_id)
        elsif blob.store_id.to_s != owner_store_id.to_s
          report_store_mismatch("belongs to store #{blob.store_id}", owner_store_id)
        end
      end

      def report_store_mismatch(reason, owner_store_id)
        Rails.logger.warn(
          "[Spree] Attached file #{blob.id} #{reason}, but #{record_type}##{record_id} (#{name}) " \
          "belongs to store #{owner_store_id}. Spree 6.1 refuses this attachment."
        )
      end
    end
  end
end
