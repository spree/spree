namespace :spree do
  namespace :upgrade do
    desc 'Adds the built-in saved reports to every store that has none (Spree 6.0). Idempotent.'
    task create_built_in_reports: :environment do
      Spree::Store.find_each do |store|
        next if store.saved_reports.seeded.exists?

        store.create_built_in_reports
        puts "  #{store.name}: added the built-in reports"
      end
    end
  end
end
