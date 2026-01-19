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
