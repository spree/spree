FactoryBot.define do
  factory :page_section, class: Spree::PageSection do
    pageable { Spree::Page.find_by!(name: 'Homepage') }
    pageable_type { 'Spree::Page' }

    trait :featured_taxons do
      type { 'Spree::PageSections::FeaturedTaxons' }
    end

    factory :featured_taxon, class: Spree::PageSections::FeaturedTaxon

    trait :header do
      type { 'Spree::PageSections::Header' }
    end

    trait :announcement_bar do
      type { 'Spree::PageSections::AnnouncementBar' }
    end

    trait :rich_text do
      type { 'Spree::PageSections::RichText' }
    end
  end
end
