# allows creditcard info to be saved to the datbase which is needed for factories to work properly
class TestCard < Spree::Creditcard
  def remove_readonly_attributes(attributes) attributes; end
end

FactoryGirl.define do
  factory :creditcard, :class => TestCard do
    verification_value 123
    month 12
    year 2013
    number '4111111111111111'
  end
end
