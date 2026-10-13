module Spree
  module MaintenanceTasks
    module Upgrade
      # Records which store owns every uploaded file, taken from the record
      # it is attached to. Files attached in more than one store are listed
      # and left for the operator to resolve.
      class UploadStores < RakeStep
        description 'maintenance_tasks.upgrade.upload_stores.description'

        runs_rake_task 'spree:uploads:assign_stores'
      end
    end
  end
end
