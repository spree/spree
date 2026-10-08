module Spree
  module MaintenanceTasks
    module Upgrade
      # Encrypts the secrets payment gateways and integrations keep in their
      # preferences.
      class EncryptSecretPreferences < RakeStep
        description 'maintenance_tasks.upgrade.encrypt_secret_preferences.description'

        runs_rake_task 'spree:upgrade:encrypt_secret_preferences'
      end
    end
  end
end
