FactoryBot.define do
  factory :page, class: Spree::Page do
    type { 'Spree::Page' }
    pageable { Spree::Theme.first || create(:theme) }
    sequence(:name) { |n| "Page #{n}" }
    meta_description { 'Page Description' }

    trait :homepage do
      name { 'Homepage' }
      type { 'Spree::Pages::Homepage' }
    end

    trait :account do
      type { 'Spree::Pages::Account' }
      name { 'Account' }
    end

    trait :preview do
      parent { create(:page) }
    end

    trait :for_store do
      pageable { Spree::Store.default }
    end
  end

  factory :custom_page, class: Spree::Pages::Custom do
    type { 'Spree::Pages::Custom' }
    pageable { Spree::Store.default }
    sequence(:name) { |n| "Custom Page #{n}" }
    meta_description { 'Page Description' }
  end
end
