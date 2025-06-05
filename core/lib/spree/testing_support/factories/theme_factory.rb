FactoryBot.define do
  factory :theme, class: Spree::Theme do
    sequence(:name) { |n| "Theme #{n}#{Kernel.rand(9999)}" }
    store { Spree::Store.default || create(:store, default: true) }

    trait :blank do
      duplicating { true }
    end

    trait :preview do
      parent { Spree::Store.default.default_theme || create(:theme, store: store) }
    end
  end
end
