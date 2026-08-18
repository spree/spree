module Spree
  module MaintenanceTasks
    module Upgrade
      # Rebuilds the search index so documents carry the field describing which
      # option values sit together on the same variant.
      #
      # Only does anything on an installation running an indexing search
      # provider; the database provider queries live tables and needs no index.
      class SearchReindex < RakeStep
        description 'maintenance_tasks.upgrade.search_reindex.description'

        runs_rake_task 'spree:search:reindex'
      end
    end
  end
end
