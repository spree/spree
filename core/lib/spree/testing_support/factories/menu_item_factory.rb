FactoryBot.define do
  factory :menu_item, class: Spree::MenuItem do
    sequence(:name) { |n| "Link no. #{n} To Somewhere" }
    item_type { 'Link' }
    linked_resource_type { 'Spree::Linkable::Uri' }

    menu
    icon
  end
end
