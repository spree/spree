FactoryBot.define do
  factory :digital_link, class: Spree::DigitalLink do
    digital_asset
    line_item
  end
end
