FactoryBot.define do
  factory :payment, class: Spree::Payment do
    order         { (cart || order_group).present? ? nil : create(:order, total: amount) }
    amount        { 45.75 }
    status        { 'checkout' }
    response_code { "BGS-#{SecureRandom.hex(6)}" }

    payment_method { create(:credit_card_payment_method, store: (order || cart || order_group).store) }
    association(:source, factory: :credit_card)

    factory :payment_with_refund do
      status { 'completed' }
      after :create do |payment|
        create(:refund, amount: 5, payment: payment)
      end
    end

    factory :custom_payment, class: Spree::Payment do
      payment_method { create(:custom_payment_method, store: order.store) }
      source { create(:payment_source, customer: order.customer, payment_method: payment_method) }
    end
  end

  factory :check_payment, class: Spree::Payment do
    amount { 45.75 }
    order  { create(:order, total: amount) }

    association(:payment_method, factory: :check_payment_method)
  end

  factory :store_credit_payment, class: Spree::Payment, parent: :payment do
    # An order group owns payments like a cart or an order does, and a split
    # checkout paid with store credit is exactly where that matters.
    payment_method { create(:store_credit_payment_method, store: (order || cart || order_group).store) }
    source do
      owner = order || cart || order_group
      create(:store_credit, store: owner.store, customer: owner.customer)
    end
  end
end
