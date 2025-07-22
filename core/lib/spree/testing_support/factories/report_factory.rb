# == Schema Information
#
# Table name: spree_reports
#
#  id          :bigint           not null, primary key
#  type        :string
#  currency    :string
#  date_from   :datetime
#  date_to     :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  store_id    :bigint           not null
#  user_id     :bigint
#
FactoryBot.define do
  factory :report, class: 'Spree::Reports::SalesTotal' do
    store { create(:store) }
    user { create(:admin_user) }
    type { 'Spree::Reports::SalesTotal' }
    currency { 'USD' }
    date_from { 1.month.ago }
    date_to { Time.current }
  end

  factory :products_performance_report, class: 'Spree::Reports::ProductsPerformance' do
    store { create(:store) }
    user { create(:admin_user) }
    type { 'Spree::Reports::ProductsPerformance' }
    currency { 'USD' }
    date_from { 1.month.ago }
    date_to { Time.current }
  end
end
