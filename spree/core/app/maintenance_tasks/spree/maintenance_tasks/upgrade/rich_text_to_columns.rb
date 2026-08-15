module Spree
  module MaintenanceTasks
    module Upgrade
      # Copies descriptions, policies and notes out of Action Text into the text
      # columns that own them in 6.0, sanitizing on the way in.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class RichTextToColumns < RakeStep
        description 'maintenance_tasks.upgrade.rich_text_to_columns.description'

        runs_rake_task 'spree:migrate_rich_text_to_columns'
      end
    end
  end
end
