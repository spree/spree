FactoryBot.define do
  factory :prototype, class: Spree::Prototype do
    name       { 'Baseball Cap' }
    properties { [build(:property)] }
  end
  factory :prototype_with_option_types, class: Spree::Prototype do
    name         { 'Baseball Cap' }
    properties   { [build(:property)] }
    option_types { [build(:option_type)] }
  end
end
