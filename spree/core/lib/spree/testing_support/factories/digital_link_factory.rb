FactoryBot.define do
  factory :digital_link, class: Spree::DigitalLink do
    digital
    line_item
  end
end
