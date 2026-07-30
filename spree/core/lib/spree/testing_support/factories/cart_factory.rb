FactoryBot.define do
  factory :cart, class: Spree::Cart do
    store { Spree::Store.find_by(default: true) || association(:store) }
    currency { 'USD' }

    factory :cart_with_line_items do
      transient do
        line_items_count { 1 }
        line_items_price { BigDecimal(10) }
      end

      after(:create) do |cart, evaluator|
        create_list(:line_item, evaluator.line_items_count, cart: cart, order: nil, price: evaluator.line_items_price)
        cart.line_items.reload
        cart.recalculate_totals!
      end
    end
  end
end
