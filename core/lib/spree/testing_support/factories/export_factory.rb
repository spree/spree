FactoryBot.define do
  factory :export, class: 'Spree::Export' do
    store { create(:store) }
    user { create(:admin_user) }
    type { 'Spree::Exports::Products' }
    format { 'csv' }

    factory :product_export, class: 'Spree::Exports::Products', parent: :export do
      type { 'Spree::Exports::Products' }
    end

    factory :order_export, class: 'Spree::Exports::Orders', parent: :export do
      type { 'Spree::Exports::Orders' }
    end

    factory :customer_export, class: 'Spree::Exports::Customers', parent: :export do
      type { 'Spree::Exports::Customers' }
    end
  end
end
