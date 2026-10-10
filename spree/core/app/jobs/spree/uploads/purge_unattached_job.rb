module Spree
  module Uploads
    # Deletes uploaded files that were never attached to anything, once they
    # are older than `Spree::Config.unattached_upload_retention_days`.
    #
    # Rails deletes nothing on its own, so an upload abandoned halfway (a
    # closed tab, a failed form) would otherwise stay in storage forever. The
    # retention outlasts an upload reference, which expires after a day, so no
    # file a client can still attach is deleted.
    #
    # Scheduled daily by the host app (`spree/spree-starter`'s recurring.yml
    # ships the entry). Continuable: the cursor is the last file handled, so a
    # deploy mid-run resumes rather than starting over.
    class PurgeUnattachedJob < Spree::BaseJob
      include ActiveJob::Continuable

      def perform
        step :purge
      end

      private

      def purge(step)
        # Only files that belong to a store: a host app may keep blobs of its
        # own outside attachments, and those are not Spree's to delete.
        blobs = ActiveStorage::Blob.unattached.where.not(store_id: nil).
                where(created_at: ...Spree::Config.unattached_upload_retention_days.days.ago)
        blobs = blobs.where(ActiveStorage::Blob.arel_table[:id].gt(step.cursor)) if step.cursor

        blobs.find_each(order: :asc) do |blob|
          purge_blob(blob)
          step.set!(blob.id)
        end
      end

      # A file attached between the query and the purge is kept. The check
      # covers databases that do not enforce the attachments foreign key; the
      # rescue covers the moment between the check and the delete on those
      # that do.
      def purge_blob(blob)
        return if blob.attachments.exists?

        blob.purge
      rescue ActiveRecord::InvalidForeignKey
        nil
      end
    end
  end
end
