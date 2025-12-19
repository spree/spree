FactoryBot.define do
  factory :page_link, class: Spree::PageLink do
    parent { Spree::PageSections::Header.first }
    linkable { Spree::Page.first }
    sequence(:label) { |n| "Page Link #{n}" }
  end
end
