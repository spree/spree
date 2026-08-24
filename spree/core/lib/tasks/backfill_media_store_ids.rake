namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Assigns a store to every media row (Spree 6.0). Idempotent — rows that
      already carry a store_id are skipped, so an interrupted run resumes for
      free.

      Media used to reach its store through its viewable. The media library
      breaks that chain: a file uploaded before anyone has decided where it
      goes has no viewable to ask, so the store moved onto the row itself.

      Rows are matched to their product's store. Anything left unowned —
      media whose viewable was deleted out from under it — goes to the default
      store, since a row with no store is invisible to every library query and
      would otherwise sit in storage with no way to find or delete it.

      Run this AFTER spree:media:migrate_master_images_to_product_media and let
      its jobs drain: that step moves media between viewables, and a row
      re-homed afterwards would keep the store stamped here.
    DESC
    task backfill_media_store_ids: :environment do
      store = Spree::Store.default
      abort '  No default store found — create a store first.' if store.nil?

      media_table = Spree::Media.table_name
      products_table = Spree::Product.table_name
      variants_table = Spree::Variant.table_name

      # Set-based updates rather than row-by-row: a catalog's media table is
      # one of the largest in the schema, and both answers are a single join
      # away in the database already.
      from_products = Spree::Media.connection.update(<<~SQL.squish)
        UPDATE #{media_table}
        SET store_id = (
          SELECT store_id FROM #{products_table}
          WHERE #{products_table}.id = #{media_table}.viewable_id
        )
        WHERE store_id IS NULL
          AND viewable_type = 'Spree::Product'
          AND EXISTS (
            SELECT 1 FROM #{products_table}
            WHERE #{products_table}.id = #{media_table}.viewable_id
          )
      SQL

      from_variants = Spree::Media.connection.update(<<~SQL.squish)
        UPDATE #{media_table}
        SET store_id = (
          SELECT #{products_table}.store_id
          FROM #{variants_table}
          INNER JOIN #{products_table} ON #{products_table}.id = #{variants_table}.product_id
          WHERE #{variants_table}.id = #{media_table}.viewable_id
        )
        WHERE store_id IS NULL
          AND viewable_type = 'Spree::Variant'
          AND EXISTS (
            SELECT 1 FROM #{variants_table}
            INNER JOIN #{products_table} ON #{products_table}.id = #{variants_table}.product_id
            WHERE #{variants_table}.id = #{media_table}.viewable_id
          )
      SQL

      orphaned = Spree::Media.unscoped.where(store_id: nil).update_all(store_id: store.id)

      puts "  Assigned #{from_products} product media row(s) and #{from_variants} variant media row(s) " \
           'from their product.'
      puts "  Assigned #{orphaned} unowned media row(s) to store #{store.name} (#{store.id})."
    end
  end
end
