namespace :spree_vies do
  desc 'Queue a VIES check for every EU VAT number never checked, or answered longer ago than SpreeVies.freshness'
  task revalidate: :environment do
    SpreeVies::RevalidateJob.perform_now
  end
end
