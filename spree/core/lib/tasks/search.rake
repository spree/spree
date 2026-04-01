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
  end
end
