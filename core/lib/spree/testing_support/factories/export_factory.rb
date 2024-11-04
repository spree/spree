# == Schema Information
#
# Table name: spree_exports
#
#  id            :uuid             not null, primary key
#  format        :integer          not null
#  number        :string(32)       not null
#  search_params :jsonb
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :uuid             not null
#  store_id      :uuid             not null
#  user_id       :uuid
#  vendor_id     :uuid
#
FactoryBot.define do
  factory :export, class: 'Spree::Export' do
    store { create(:store) }
    user { create(:admin_user) }
    type { 'Spree::Export::Products' }
    format { 'csv' }

    factory :product_export, class: 'Spree::Exports::Products', parent: :export do
      type { 'Spree::Exports::Products' }
    end

    factory :order_export, class: 'Spree::Exports::Orders', parent: :export do
      type { 'Spree::Exports::Orders' }
    end
  end
end
