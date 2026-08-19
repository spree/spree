module Spree
  module MaintenanceTasks
    module Upgrade
      # Moves images pinned to the hidden master variant onto product-level media.
      #
      # Enqueues a job per product, so the storefront keeps working while they
      # drain.
      class MasterImagesToProductMedia < RakeStep
        description 'maintenance_tasks.upgrade.master_images_to_product_media.description'

        runs_rake_task 'spree:media:migrate_master_images_to_product_media'
      end
    end
  end
end
