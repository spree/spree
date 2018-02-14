FactoryBot.define do
  factory :tag, class: Spree::Tag do
    sequence(:name) { |n| "Tag ##{n} - #{Kernel.rand(9999)}" }
  end
end
