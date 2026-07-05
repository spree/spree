# frozen_string_literal: true

namespace :spree do
  namespace :role_users do
    desc <<~DESC
      Backfills +spree_role_users.store_id+ for store-scoped role assignments
      (resource_type = 'Spree::Store') by copying +resource_id+. Idempotent —
      only rows with a null +store_id+ are touched.

      Role resolution (Spree::Ability) scopes by +store_id+, so run this after
      adding the column. Until it does, the +spree_admin?+ fallback keeps store
      admins authorized. Role assignments on non-store resources (e.g.
      Spree::Vendor) are backfilled by the owning extension.
    DESC
    task backfill_store_ids: :environment do
      count = Spree::RoleUser.where(resource_type: Spree::Store.name, store_id: nil)
                             .update_all('store_id = resource_id')
      puts "  Backfilled store_id on #{count} store-scoped role assignment(s)."
    end
  end
end
