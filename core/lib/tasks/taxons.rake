namespace :spree do
  namespace :taxons do
    desc 'Reset children_count counter cache on taxons'
    task reset_children_count: :environment do |_t, _args|
      puts 'Resetting children_count counter cache...'
      Spree::Taxon.in_batches.update_all(
        "children_count = (SELECT COUNT(*) FROM spree_taxons AS children WHERE children.parent_id = spree_taxons.id)"
      )
      puts 'Done!'
    end

    desc 'Reset classification_count counter cache on taxons'
    task reset_classification_count: :environment do |_t, _args|
      puts 'Resetting classification_count counter cache...'
      Spree::Taxon.in_batches.update_all(
        "classification_count = (SELECT COUNT(*) FROM spree_products_taxons WHERE spree_products_taxons.taxon_id = spree_taxons.id)"
      )
      puts 'Done!'
    end
  end
end
