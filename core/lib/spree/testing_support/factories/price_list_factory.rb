FactoryBot.define do
  factory :price_list, class: Spree::PriceList do
    sequence(:name) { |n| "Price List #{n}" }
    priority { 0 }
    status { 'active' }
    match_policy { 'all' }

    trait :inactive do
      status { 'inactive' }
    end

    trait :scheduled do
      status { 'scheduled' }
    end

    trait :with_date_range do
      starts_at { 1.day.ago }
      ends_at { 1.day.from_now }
    end

    trait :high_priority do
      priority { 100 }
    end

    trait :any_match do
      match_policy { 'any' }
    end
  end
end
