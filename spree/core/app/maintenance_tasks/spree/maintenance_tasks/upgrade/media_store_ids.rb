module Spree
  module MaintenanceTasks
    module Upgrade
      # Stamps every media row with the store it belongs to, so the media
      # library can list files that are not attached to anything yet.
      class MediaStoreIds < RakeStep
        description 'maintenance_tasks.upgrade.media_store_ids.description'

        runs_rake_task 'spree:upgrade:backfill_media_store_ids'
      end
    end
  end
end
