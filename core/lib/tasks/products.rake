namespace :spree do
  namespace :products do
    desc 'Reset counter caches (variant_count, classification_count, total_image_count) on products'
    task reset_counter_caches: :environment do |_t, _args|
      puts 'Resetting product counter caches...'

      Spree::Product.find_each do |product|
        product.update_columns(
          variant_count: product.variants.count,
          classification_count: product.classifications.count,
          total_image_count: product.variant_images.count,
          updated_at: Time.current
        )
        print '.'
      end

      puts "\nDone!"
    end

    desc 'Enqueue background jobs to populate product metrics for all store products'
    task populate: :environment do
      total_count = 0

      Spree::StoreProduct.in_batches(of: 100) do |batch|
        jobs = batch.pluck(:product_id, :store_id).map do |product_id, store_id|
          Spree::Products::RefreshMetricsJob.new(product_id, store_id)
        end
        ActiveJob.perform_all_later(jobs)
        total_count += jobs.size
        print '.'
      end

      if total_count.zero?
        puts 'No store products found.'
      else
        puts "\nEnqueued #{total_count} jobs to refresh product metrics."
      end
    end
  end
end
