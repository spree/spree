namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Populates +spree_products.store_id+ and +spree_product_publications+ from the legacy
      +spree_products_stores+ join. Idempotent — re-running skips products that
      already have a +store_id+ and channels that already have a publication for
      the product.

      Run once after upgrading to Spree 5.5+. Multi-store merchants must install
      +spree_multi_store+ before running; running on a multi-store catalog without
      the extension picks the earliest +spree_products_stores+ row (by
      +created_at+) as the product's home store.
    DESC
    task populate_publications: :environment do
      unless ActiveRecord::Base.connection.table_exists?(Spree::StoreProduct.table_name)
        puts "  #{Spree::StoreProduct.table_name} table not found — nothing to migrate."
        next
      end

      batch_size = (ENV['BATCH_SIZE'] || 1_000).to_i
      publications_created = 0

      # Pass 1: per store, batch-publish products onto the store's default
      # channel via +Channel#add_products+. One upsert + one touch_all per
      # batch beats the previous per-product loop by orders of magnitude on
      # large catalogs. +add_products+ is upsert-based with +on_duplicate:
      # :skip+, so existing publications on re-run are no-ops.
      Spree::Store.find_each do |store|
        channel = store.default_channel
        unless channel
          puts "  Store '#{store.name}' has no default channel — skipping."
          next
        end

        store_publications = 0
        Spree::StoreProduct.where(store_id: store.id).in_batches(of: batch_size) do |batch|
          store_publications += channel.add_products(batch.pluck(:product_id))
        end

        publications_created += store_publications
        puts "  Store '#{store.name}': created #{store_publications} publication(s)" if store_publications.positive?
      end

      # Pass 2: assign +store_id+ on products that still don't have one,
      # using the earliest legacy row per product.
      products_processed = 0

      Spree::Product.where(store_id: nil).find_each(batch_size: batch_size) do |product|
        store_id = Spree::StoreProduct.where(product_id: product.id).order(:created_at).limit(1).pick(:store_id)
        next unless store_id

        product.update_column(:store_id, store_id)
        products_processed += 1
      end

      puts "  Processed #{products_processed} products"
      puts "  Created #{publications_created} publications"
    end
  end
end
