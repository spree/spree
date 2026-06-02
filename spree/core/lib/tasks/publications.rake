namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Populates +spree_products.store_id+ and +spree_product_publications+ from the legacy
      +spree_products_stores+ join. Idempotent — re-running skips products that
      already have a +store_id+ and channels that already have a publication for
      the product.

      Run once after upgrading to Spree 5.5+. Multi-store merchants must install
      +spree_multi_store+ before running; running on a multi-store catalog without
      the extension picks one "home" store per product per the rules below:

        1. The store flagged +default: true+ if the product is published there
        2. Otherwise the first store (by +spree_products_stores.created_at+)
    DESC
    task populate_publications: :environment do
      legacy_table = 'spree_products_stores'

      unless ActiveRecord::Base.connection.table_exists?(legacy_table)
        puts "  #{legacy_table} table not found — nothing to migrate."
        next
      end

      products_processed = 0
      publications_created = 0

      # Legacy +spree_products_stores+ pre-5.5 carries only product_id,
      # store_id, created_at (plus the +units_sold_count+/+revenue+ columns
      # we no longer read here). Channel attribution + publication windows
      # are derived from the destination store's default channel.
      Spree::Product.where(store_id: nil).find_each do |product|
        sql = ActiveRecord::Base.sanitize_sql_array([
          "SELECT store_id, created_at FROM #{legacy_table} WHERE product_id = ? ORDER BY created_at ASC",
          product.id
        ])
        rows = ActiveRecord::Base.connection.select_all(sql).to_a

        next if rows.empty?

        home_store_id = pick_home_store(rows)
        store_ids = rows.map { |r| r['store_id'] }.uniq

        # Build publications + store_id assignment atomically. If the
        # publication writes fail (validation, deadlock, etc.) we rollback
        # so a re-run can retry — the +store_id IS NULL+ filter at the top
        # of the loop only matches products that didn't finish.
        ActiveRecord::Base.transaction do
          store_ids.each do |store_id|
            channel = Spree::Store.find(store_id).default_channel
            next unless channel

            publication = Spree::ProductPublication.find_or_initialize_by(
              product_id: product.id,
              channel_id: channel.id
            )

            next if publication.persisted?

            publication.save!
            publications_created += 1
          end

          product.update_column(:store_id, home_store_id)
        end

        products_processed += 1
      end

      puts "  Processed #{products_processed} products"
      puts "  Created #{publications_created} publications"
    end

    # When a product was attached to multiple stores via the legacy join,
    # pick the default store if it's in the list — otherwise the earliest
    # row (rows are pre-sorted by +created_at+).
    def pick_home_store(rows)
      default_store_id = Spree::Store.find_by(default: true)&.id
      if default_store_id && rows.any? { |r| r['store_id'] == default_store_id }
        default_store_id
      else
        rows.first['store_id']
      end
    end
  end
end
