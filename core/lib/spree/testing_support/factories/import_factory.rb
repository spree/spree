FactoryBot.define do
  factory :import, class: 'Spree::Import' do
    store { create(:store) }
    user { create(:admin_user) }
    type { 'Spree::Imports::Products' }

    factory :product_import, class: 'Spree::Imports::Products' do
      type { 'Spree::Imports::Products' }
    end
  end
end
