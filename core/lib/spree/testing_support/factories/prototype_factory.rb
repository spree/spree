FactoryGirl.define do
  factory :prototype, class: Spree::Prototype do
    name 'Baseball Cap'
    properties { [create(:property)] }
  end
end
