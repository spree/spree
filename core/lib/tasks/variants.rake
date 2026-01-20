namespace :spree do
  namespace :variants do
    desc 'Reset image_count counter cache on variants'
    task reset_counter_caches: :environment do |_t, _args|
      puts 'Resetting variant counter caches...'

      Spree::Variant.find_each do |variant|
        variant.update_columns(
          image_count: variant.images.count,
          updated_at: Time.current
        )
        print '.'
      end

      puts "\nDone!"
    end
  end
end
