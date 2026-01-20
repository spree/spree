namespace :spree do
  namespace :variants do
    desc 'Reset image_count counter cache on variants'
    task reset_image_count: :environment do |_t, _args|
      puts 'Resetting image_count counter cache...'
      Spree::Variant.in_batches.update_all(
        "image_count = (SELECT COUNT(*) FROM spree_assets WHERE spree_assets.viewable_id = spree_variants.id AND spree_assets.viewable_type = 'Spree::Variant' AND spree_assets.type = 'Spree::Image')"
      )
      puts 'Done!'
    end
  end
end
