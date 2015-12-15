FactoryGirl.define do
  factory :state, class: Spree::State do
    sequence(:name, &'State %d'.method(:%))
    sequence(:abbr) { |n| '%02d' % (n % 100) }
    country
  end
end
