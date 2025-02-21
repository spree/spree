FactoryBot.define do
  factory :page_section, class: Spree::PageSection do
    pageable { Spree::Page.find_by!(name: 'Homepage') }
    pageable_type { 'Spree::Page' }

    factory :featured_taxons_page_section, class: Spree::PageSections::FeaturedTaxons

    factory :featured_taxon_page_section, class: Spree::PageSections::FeaturedTaxon

    factory :header_page_section, class: Spree::PageSections::Header

    factory :announcement_bar_page_section, class: Spree::PageSections::AnnouncementBar

    factory :rich_text_page_section, class: Spree::PageSections::RichText
  end
end
