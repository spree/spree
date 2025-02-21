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
  end
end
