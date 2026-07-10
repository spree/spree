namespace :spree do
  namespace :taxons do
    desc 'Backfill spree_taxons.store_id from each taxon\'s taxonomy (or parent)'
    task backfill_store_id: :environment do |_t, _args|
      puts 'Backfilling taxon store_id from taxonomy...'

      # Resolve per-taxonomy and update by id — never reference a joined table in
      # an update_all SET clause. It is not portable: on some adapter / Rails
      # version combinations (e.g. Rails 7.2 on PostgreSQL) update_all-with-join
      # is rewritten to `... WHERE id IN (subquery)`, leaving the joined alias out
      # of scope in the SET and raising PG::UndefinedTable ("missing FROM-clause
      # entry"). It fails at parse time, even when no rows need changing.
      Spree::Taxonomy.where.not(store_id: nil).find_each do |taxonomy|
        Spree::Taxon.unscoped.where(store_id: nil, taxonomy_id: taxonomy.id).
          in_batches(of: 1000).update_all(store_id: taxonomy.store_id)
        print '.'
      end

      puts "\nResolving taxonomy-less taxons through the parent chain..."

      # Mirror Spree::Taxon#ensure_store: taxonomy-less rows inherit their parent's
      # store. Loop so a chain of unbackfilled ancestors resolves top-down — each
      # pass pushes an already-resolved parent's store onto its children.
      loop do
        updated = 0

        # Resolved parents that still have children missing a store form the
        # frontier; push each store down in one UPDATE per (store, id batch).
        frontier = Spree::Taxon.unscoped.where.not(store_id: nil).
                   where(id: Spree::Taxon.unscoped.where(store_id: nil).select(:parent_id))
        frontier.pluck(:id, :store_id).group_by(&:last).each do |store_id, rows|
          rows.map(&:first).each_slice(1000) do |parent_ids|
            updated += Spree::Taxon.unscoped.where(store_id: nil, parent_id: parent_ids).
                       update_all(store_id: store_id)
          end
        end

        print '.'
        break if updated.zero?
      end

      puts "\nDone!"
    end

    # Recomputes the descendant-inclusive products_count for every taxon, in
    # batches. Shared by the dedicated task and reset_counter_caches.
    backfill_products_count = lambda do
      Spree::Taxon.unscoped.in_batches(of: 1000) do |batch|
        Spree::Taxon.recalculate_products_count(batch.pluck(:id))
        print '.'
      end
    end

    desc 'Backfill the descendant-inclusive products_count on every taxon'
    task backfill_products_count: :environment do |_t, _args|
      puts 'Backfilling taxon products_count...'
      backfill_products_count.call
      puts "\nDone!"
    end

    desc 'Reset counter caches (children_count, products_count) on taxons'
    task reset_counter_caches: :environment do |_t, _args|
      puts 'Resetting taxon counter caches...'

      Spree::Taxon.find_each do |taxon|
        taxon.update_columns(
          children_count: taxon.children.count,
          updated_at: Time.current
        )
        print '.'
      end

      puts "\nRecomputing products_count..."
      backfill_products_count.call

      puts "\nDone!"
    end
  end
end
