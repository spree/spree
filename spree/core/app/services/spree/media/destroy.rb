module Spree
  class Media
    # Deletes a library file everywhere at once: every placement sharing its
    # blob, every plain attachment (a category image slot, a store logo)
    # holding it, then the row itself — whose purge takes the blob with it once
    # nothing references it. The alternative was refusing until the merchant
    # cleared each use by hand, which is busywork the usage list already knows
    # how to do.
    #
    # Scoped to the file's own store: a blob another tenant happens to share
    # keeps their attachments, and the foreign key keeps the file in storage
    # for them. Rich text embeds are plain URLs with nothing to detach — those
    # descriptions lose the image, which is what the caller's confirmation
    # acknowledged.
    class Destroy
      prepend Spree::ServiceModule::Base

      # @param media [Spree::Media] the library row being deleted
      # @return [Spree::ServiceModule::Result]
      def call(media:)
        # Only the file this row *is*, never its poster: a poster is a still
        # another row may legitimately use as its own picture, and deleting a
        # video must not take that image with it. The row's own poster goes
        # when the row does.
        blob_ids = [media.attachment_blob&.id].compact

        # Detaching is collected inside the transaction and enqueued after it
        # commits: purge_later hands the file to a worker that may run before
        # the transaction ends, so a rollback would leave the rows intact with
        # their file already gone.
        detachable = nil

        ApplicationRecord.transaction do
          destroy_placements(media, blob_ids)
          detachable = plain_attachments(media, blob_ids)
          media.destroy!
        end

        # ActiveRecord::Rollback is swallowed by the transaction block, so a
        # surviving row is how a rolled-back delete reports itself. Detaching
        # then would strip the file from records the delete did not remove.
        return failure(media) if media.persisted?

        detachable.each(&:purge_later)

        success(media)
      end

      private

      # Other rows sharing the file — placements on products, categories,
      # collections. destroy, not delete: the callbacks are what refresh the
      # owners' thumbnails and counters.
      def destroy_placements(media, blob_ids)
        return if blob_ids.empty?

        Spree::Media
          .where(store_id: media.store_id)
          .where.not(id: media.id)
          .joins(:attachment_attachment)
          .where(ActiveStorage::Attachment.table_name => { blob_id: blob_ids })
          .find_each(&:destroy!)
      end

      # The plain attachments this store holds on the file — a category image
      # slot, a store logo. Media rows are handled by destroy_placements.
      #
      # @return [Array<ActiveStorage::Attachment>]
      def plain_attachments(media, blob_ids)
        ActiveStorage::Attachment.where(blob_id: blob_ids).select do |attachment|
          owner = attachment.record
          next false if owner.blank? || owner.is_a?(Spree::Media)

          owned_by_store?(owner, media.store_id)
        end
      end

      # Ownership must be proven, never assumed. A Spree::Store has no
      # store_id of its own, so treating a blank one as "mine" made every
      # other store's logo look local — and deleting a file would strip it.
      def owned_by_store?(owner, store_id)
        return owner.id == store_id if owner.is_a?(Spree::Store)

        owner.try(:store_id) == store_id
      end
    end
  end
end
