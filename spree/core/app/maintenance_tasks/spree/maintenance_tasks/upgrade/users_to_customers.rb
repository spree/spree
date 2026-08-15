module Spree
  module MaintenanceTasks
    module Upgrade
      # Copies the legacy Devise user table onto the gem-owned customer model
      # and re-points every polymorphic reference that named the old class.
      #
      # Two of its parameters are questions only an operator can answer: whether
      # a Devise pepper was ever configured (an encrypted password cannot be
      # read without knowing, and Devise is gone by the time this runs), and
      # what to do with source rows that cannot be copied.
      class UsersToCustomers < RakeStep
        description 'maintenance_tasks.upgrade.users_to_customers.description'

        runs_rake_task 'spree:upgrade:migrate_users_to_customers'

        attribute :confirm_no_pepper, :boolean, default: false
        attribute :skip_invalid_rows, :boolean, default: false
        attribute :source_user_table, :string
        attribute :source_user_type, :string
        attribute :batch_size, :integer, default: 1_000

        passes_to_environment :confirm_no_pepper, as: 'CONFIRM_NO_PEPPER'
        passes_to_environment :skip_invalid_rows, as: 'SKIP_INVALID_ROWS'
        passes_to_environment :source_user_table, as: 'SOURCE_USER_TABLE'
        passes_to_environment :source_user_type, as: 'SOURCE_USER_TYPE'
        passes_to_environment :batch_size, as: 'BATCH_SIZE'
      end
    end
  end
end
