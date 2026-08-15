module Spree
  module MaintenanceTasks
    module Upgrade
      # Splits taxons into categories and collections, carrying rules, membership,
      # translations and media across, then severs the taxonomy structure.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class TaxonsToCategoriesAndCollections < RakeStep
        description 'maintenance_tasks.upgrade.taxons_to_categories_and_collections.description'

        runs_rake_task 'spree:migrate_taxons_to_categories_and_collections'
      end
    end
  end
end
