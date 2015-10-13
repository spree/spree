FactoryGirl.define do
  factory :credit_card, class: Spree::CreditCard do
    transient do
      user nil
      user_id nil
      default false
    end

    verification_value 123
    month 12
    year { 1.year.from_now.year }
    number '4111111111111111'
    name 'Spree Commerce'
    association(:payment_method, factory: :credit_card_payment_method)

    after(:build) do |credit_card, evaluator|
      credit_card.create_user_payment_source(
        user_id: evaluator.user_id || evaluator.user.try(:id),
        default: evaluator.default
      )
    end
  end
end
