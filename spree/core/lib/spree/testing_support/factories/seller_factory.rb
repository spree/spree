FactoryBot.define do
  factory :seller, class: Spree::Seller do
    sequence(:name) { |n| "Seller #{n}" }
    store { Spree::Store.default || create(:store) }
    status { 'pending' }

    trait :approved do
      status { 'approved' }
      terms_accepted_at { Time.current }
    end

    trait :onboarding do
      status { 'onboarding' }
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :on_holiday do
      status { 'approved' }
      holiday_mode_until { 2.weeks.from_now }
    end

    trait :with_logo do
      after(:create) do |seller|
        seller.logo.attach(
          io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'thinking-cat.jpg'
        )
      end
    end
  end
end
