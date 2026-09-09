module Spree
  module MaintenanceTasks
    module Upgrade
      # Records where each existing media file is already used, so the library
      # can report what a file is attached to before it is deleted.
      class LibraryMediaPlacements < RakeStep
        description 'maintenance_tasks.upgrade.library_media_placements.description'

        runs_rake_task 'spree:upgrade:backfill_library_media_placements'
      end
    end
  end
end
