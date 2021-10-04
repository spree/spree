FactoryBot.define do
  factory :payment, class: Spree::Payment do
    order
    amount        { 45.75 }
    state         { 'checkout' }
    response_code { '12345' }

    payment_method { create(:credit_card_payment_method, stores: [order.store]) }
    association(:source, factory: :credit_card)

    factory :payment_with_refund do
      state { 'completed' }
      after :create do |payment|
        create(:refund, amount: 5, payment: payment)
      end
    end
  end

  factory :check_payment, class: Spree::Payment do
    amount { 45.75 }
    order

    association(:payment_method, factory: :check_payment_method)
  end

  factory :store_credit_payment, class: Spree::Payment, parent: :payment do
    payment_method { create(:store_credit_payment_method, stores: [order.store]) }
    source { create(:store_credit, store: order.store, user: order.user) }
  end
end
