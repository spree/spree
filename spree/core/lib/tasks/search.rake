namespace :spree do
  namespace :search do
    desc 'Reindex all products in the search provider'
    task reindex: :environment do
      Spree::Store.all.find_each do |store|
        provider = Spree.search_provider.constantize.new(store)
        total = store.products.count

        puts "Reindexing #{store.name} (#{total} products) using #{Spree.search_provider}..."
        indexed = provider.reindex(store.products.preload_associations_lazily)
        puts "Done. #{indexed || total} documents enqueued."
      end
    end

    desc 'Enable typo tolerance for PostgreSQL full-text search (the pg_trgm extension)'
    task enable_typo_tolerance: :environment do
      abort 'Typo tolerance needs PostgreSQL.' unless Spree.postgres?

      connection = Spree::Product.connection
      unless connection.extension_available?('pg_trgm')
        abort 'The pg_trgm extension is not available on this database server. Ask your database provider to allow it, then run this task again.'
      end

      connection.enable_extension('pg_trgm')
      puts 'Typo tolerance is on. Restart the application, and run `bin/rails db:schema:dump` so the schema file records the extension.'
    end
  end
end
