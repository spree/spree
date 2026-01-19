namespace :spree do
  namespace :products do
    desc 'Reset variant_count counter cache on products'
    task reset_variant_count: :environment do |_t, _args|
      puts 'Resetting variant_count counter cache...'
      Spree::Product.in_batches.update_all(
        "variant_count = (SELECT COUNT(*) FROM spree_variants WHERE spree_variants.product_id = spree_products.id AND spree_variants.is_master = false AND spree_variants.deleted_at IS NULL)"
      )
      puts 'Done!'
    end
  end
end
