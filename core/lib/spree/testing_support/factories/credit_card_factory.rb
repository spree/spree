# allows credit card info to be saved to the database which is needed for factories to work properly
class TestCard < Spree::CreditCard
  def remove_readonly_attributes(attributes) attributes; end
end

FactoryGirl.define do
  factory :credit_card, class: TestCard do
    verification_value 123
    month 12
    year { Date.year }
    number '4111111111111111'
  end
end
