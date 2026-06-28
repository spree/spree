FactoryBot.define do
  factory :export, class: 'Spree::Export' do
    association :store, factory: :store
    association :user, factory: :admin_user
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

    factory :coupon_code_export, class: 'Spree::Exports::CouponCodes', parent: :export do
      type { 'Spree::Exports::CouponCodes' }
    end
  end
end
