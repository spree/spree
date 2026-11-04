FactoryBot.define do
  factory :payment_method_rule, class: Spree::PaymentMethodRule do
    payment_method { association(:check_payment_method) }

    factory :channel_payment_method_rule, class: Spree::PaymentMethodRules::ChannelRule
    factory :market_payment_method_rule, class: Spree::PaymentMethodRules::MarketRule
    factory :order_total_payment_method_rule, class: Spree::PaymentMethodRules::OrderTotalRule
    factory :customer_group_payment_method_rule, class: Spree::PaymentMethodRules::CustomerGroupRule
    factory :company_payment_method_rule, class: Spree::PaymentMethodRules::CompanyRule
  end
end
