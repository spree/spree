namespace :spree do
  namespace :products do
    desc 'Reset counter caches (variant_count, categories_count, media_count) on products'
    task reset_counter_caches: :environment do |_t, _args|
      puts 'Resetting product counter caches...'

      Spree::Product.find_each do |product|
        total_media = product.media.count + product.variant_images.where.not(id: product.media.select(:id)).count

        product.update_columns(
          variant_count: product.variants.count,
          categories_count: product.product_categories.count,
          media_count: total_media,
          updated_at: Time.current
        )
        print '.'
      end

      puts "\nDone!"
    end

    desc 'Enqueue background jobs to populate product metrics for every product'
    task populate_metrics: :environment do
      total_count = 0

      Spree::Product.in_batches(of: 100) do |batch|
        jobs = batch.pluck(:id).map { |product_id| Spree::Products::RefreshMetricsJob.new(product_id) }
        ActiveJob.perform_all_later(jobs)
        total_count += jobs.size
        print '.'
      end

      if total_count.zero?
        puts 'No products found.'
      else
        puts "\nEnqueued #{total_count} jobs to refresh product metrics."
      end
    end
  end
end
