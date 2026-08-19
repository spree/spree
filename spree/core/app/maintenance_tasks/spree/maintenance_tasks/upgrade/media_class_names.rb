module Spree
  module MaintenanceTasks
    module Upgrade
      # Renames the stored class names that said Asset to Media, following the
      # model rename.
      class MediaClassNames < RakeStep
        description 'maintenance_tasks.upgrade.media_class_names.description'

        runs_rake_task 'spree:migrate_media_class_names'
      end
    end
  end
end
