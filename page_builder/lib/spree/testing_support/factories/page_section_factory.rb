FactoryBot.define do
  factory :page_section, class: Spree::PageSection do
    pageable { Spree::Page.find_by!(name: 'Homepage') }

    trait :without_links do
      do_not_create_links { true }
    end

    factory :featured_taxons_page_section, class: Spree::PageSections::FeaturedTaxons

    factory :featured_taxon_page_section, class: Spree::PageSections::FeaturedTaxon

    factory :header_page_section, class: Spree::PageSections::Header

    factory :announcement_bar_page_section, class: Spree::PageSections::AnnouncementBar

    factory :rich_text_page_section, class: Spree::PageSections::RichText

    factory :newsletter_page_section, class: Spree::PageSections::Newsletter

    factory :video_page_section, class: Spree::PageSections::Video

    factory :image_with_text_page_section, class: Spree::PageSections::ImageWithText

    factory :featured_posts_page_section, class: Spree::PageSections::FeaturedPosts
  end
end
