FactoryBot.define do
  factory :page_block, class: Spree::PageBlock do
    section { create(:page_section) }

    trait :buttons do
      type { 'Spree::PageBlocks::Buttons' }
    end

    trait :nav do
      section { create(:header_page_section) }

      type { 'Spree::PageBlocks::Nav' }
    end

    trait :heading do
      type { 'Spree::PageBlocks::Heading' }
    end

    factory :buttons_block, traits: [:buttons], class: Spree::PageBlocks::Buttons
    factory :heading_block, traits: [:heading], class: Spree::PageBlocks::Heading
  end
end
