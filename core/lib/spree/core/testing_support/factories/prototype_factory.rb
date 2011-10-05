FactoryGirl.define do
  factory :prototype do
    name 'Baseball Cap'
    properties { [Factory(:property)] }
  end
end
