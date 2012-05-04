FactoryGirl.define do
  factory :prototype, :class => Spree::Prototype do
    name 'Baseball Cap'
    properties { [FactoryGirl.create(:property)] }
  end
end
