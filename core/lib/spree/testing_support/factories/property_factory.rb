FactoryGirl.define do
  factory :property, class: Spree::Property do
    sequence(:name) { |n| "baseball_cap_color_#{n}" }
    presentation 'cap color'
  end
end
