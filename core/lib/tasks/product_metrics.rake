namespace :spree do
  namespace :product_metrics do
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
