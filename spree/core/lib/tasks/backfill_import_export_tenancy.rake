namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Fills in store_id (and seller_id where one applies) on every import
      (Spree 6.0). Idempotent — rows that already carry a store_id are skipped,
      so an interrupted run resumes for free.

      An import used to carry a polymorphic `owner` that was either a Store or
      a Seller, never both. A seller-owned row therefore had no store on it at
      all, which is why a marketplace operator's list could not include the
      imports their own sellers ran. Both axes now live on the row, matching
      Spree::Export: store_id is always present, and seller_id is null for the
      operator's own imports.

      Rows owned by a store keep that store and stay first-party. Rows owned by
      a seller take that seller, and their store is read from the seller.
      Anything left without a store — an import whose owner was deleted out
      from under it — goes to the default store, since a row with no store is
      invisible to every scoped query and would otherwise be unreachable.

      Exports need no data step: they have always carried store_id, and the
      seller_id column this release adds is new for everyone (the association
      shipped in 5.6 with no column behind it, so nothing was ever written).
    DESC
    task backfill_import_export_tenancy: :environment do
      imports_table = Spree::Import.table_name
      sellers_table = Spree::Seller.table_name
      stores_table = Spree::Store.table_name

      pending = Spree::Import.where(store_id: nil).count
      if pending.zero?
        puts '  Every import already carries a store — nothing to do.'
        next
      end

      puts "  #{pending} import(s) to place."

      # Set-based updates rather than row-by-row: both answers are already a
      # single join away, and an installation that seeded a catalog by CSV can
      # have a lot of these.
      # The EXISTS guard matters as much here as on the seller branch below: a
      # store that has since been deleted leaves a dangling id, and writing it
      # would make store_id non-NULL without pointing anywhere — which the
      # orphan sweep at the end then skips, leaving the row invisible to every
      # scoped query with no second chance to place it.
      from_stores = Spree::Import.connection.update(<<~SQL.squish)
        UPDATE #{imports_table}
        SET store_id = owner_id
        WHERE store_id IS NULL
          AND owner_type = 'Spree::Store'
          AND EXISTS (
            SELECT 1 FROM #{stores_table}
            WHERE #{stores_table}.id = #{imports_table}.owner_id
          )
      SQL

      # A seller's import takes the seller, and its store comes from that
      # seller — the same derivation `Import#store` used to do at read time.
      from_sellers = Spree::Import.connection.update(<<~SQL.squish)
        UPDATE #{imports_table}
        SET seller_id = owner_id,
            store_id = (
              SELECT store_id FROM #{sellers_table}
              WHERE #{sellers_table}.id = #{imports_table}.owner_id
            )
        WHERE store_id IS NULL
          AND owner_type = 'Spree::Seller'
          AND EXISTS (
            SELECT 1 FROM #{sellers_table}
            WHERE #{sellers_table}.id = #{imports_table}.owner_id
          )
      SQL

      puts "  #{from_stores} placed from a store owner."
      puts "  #{from_sellers} placed from a seller owner."

      orphaned = Spree::Import.where(store_id: nil)
      if orphaned.exists?
        store = Spree::Store.default
        if store.nil?
          puts "  #{orphaned.count} import(s) have no resolvable owner and there is no default store to place them in."
          puts '  Create a store and re-run, or delete these rows.'
        else
          count = orphaned.update_all(store_id: store.id)
          puts "  #{count} orphaned import(s) placed in the default store (#{store.name})."
        end
      end

      remaining = Spree::Import.where(store_id: nil).count
      puts remaining.zero? ? '  Done — every import carries a store.' : "  #{remaining} import(s) still unplaced."
    end
  end
end
