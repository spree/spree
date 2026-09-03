FactoryBot.define do
  factory :saved_report, class: Spree::SavedReport do
    store { Spree::Store.default }
    sequence(:name) { |n| "Report #{n}" }
    query { { 'metrics' => %w[gross_revenue orders_count], 'dimensions' => %w[channel] } }
  end
end
