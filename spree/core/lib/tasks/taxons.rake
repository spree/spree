namespace :spree do
  namespace :taxons do
    desc 'Reset counter caches (children_count, classification_count) on taxons'
    desc 'Backfill spree_taxons.store_id from each taxon\'s taxonomy'
    task backfill_store_id: :environment do |_t, _args|
      puts 'Backfilling taxon store_id from taxonomy...'

      Spree::Taxon.unscoped.where(store_id: nil).in_batches(of: 1000) do |batch|
        batch.joins(:taxonomy).update_all('store_id = spree_taxonomies.store_id')
        print '.'
      end

      puts "\nDone!"
    end
    task reset_counter_caches: :environment do |_t, _args|
      puts 'Resetting taxon counter caches...'

      Spree::Taxon.find_each do |taxon|
        taxon.update_columns(
          children_count: taxon.children.count,
          classification_count: taxon.classifications.count,
          updated_at: Time.current
        )
        print '.'
      end

      puts "\nDone!"
    end
  end
end
