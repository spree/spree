namespace :spree do
  namespace :images do
    desc 'Backfill thumbnail_id for all variants and products'
    task backfill_thumbnails: :environment do
      puts 'Backfilling variant thumbnails...'
      Spree::Variant.where(thumbnail_id: nil).where.not(image_count: 0).find_each do |variant|
        first_image = variant.images.order(:position).first
        variant.update_column(:thumbnail_id, first_image.id) if first_image
      end

      puts 'Backfilling product thumbnails...'
      Spree::Product.where(thumbnail_id: nil).where.not(total_image_count: 0).find_each do |product|
        first_image = product.variant_images.order(:position).first
        product.update_column(:thumbnail_id, first_image.id) if first_image
      end

      puts 'Done!'
    end
  end
end
