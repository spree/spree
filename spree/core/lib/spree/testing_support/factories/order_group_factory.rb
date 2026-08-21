FactoryBot.define do
  factory :order_group, class: Spree::OrderGroup do
    store { Spree::Store.default || create(:store) }
    customer
    currency { 'USD' }
    email { customer&.email }

    trait :with_orders do
      transient do
        sellers_count { 2 }
      end

      after(:create) do |group, evaluator|
        evaluator.sellers_count.times do |index|
          create(
            :order,
            store: group.store,
            order_group: group,
            seller: create(:seller, :approved, store: group.store),
            number: "#{group.number}-#{index + 1}",
            customer: group.customer,
            currency: group.currency
          )
        end
        group.orders.reload
      end
    end
  end
end
