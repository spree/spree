namespace :spree do
  namespace :taxons do
    desc 'Reset counter caches (children_count, classification_count) on taxons'
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
