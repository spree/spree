namespace :spree do
  namespace :upgrade do
    desc 'Adds the built-in saved reports to every store that has none (Spree 6.0). Idempotent.'
    task create_built_in_reports: :environment do
      Spree::Store.find_each do |store|
        puts "  #{store.name}: added the built-in reports" if store.create_built_in_reports
      end
    end
  end
end
