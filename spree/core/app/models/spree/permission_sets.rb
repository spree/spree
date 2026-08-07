module Spree
  # Removed in Spree 6.0 — roles are data now (docs/plans/6.0-admin-rbac.md).
  # The module survives only so 5.x initializers referencing the old set
  # classes fail at boot with directions instead of a bare NameError.
  module PermissionSets
    UPGRADE_GUIDE_URL = 'https://spreecommerce.org/docs/developer/upgrades/5.6-to-6.0'

    def self.const_missing(name)
      raise Spree::PermissionConfiguration::PermissionSetsRemovedError,
            "Spree::PermissionSets::#{name} was removed in Spree 6.0. Roles and their " \
            'permissions are data now — manage them in the dashboard (Settings → Roles), ' \
            'via the Admin API, or in seeds. Remove the permission lines from ' \
            "config/initializers/spree.rb and recreate custom roles before deploying. " \
            "Upgrade guide: #{UPGRADE_GUIDE_URL}"
    end
  end
end
