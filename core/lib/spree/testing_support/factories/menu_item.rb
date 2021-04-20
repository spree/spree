FactoryBot.define do
  factory :menu_item, class: Spree::MenuItem do
    name { 'Link To Somewhere' }
    item_type { 'Link' }
    linked_resource_type { 'URL' }
  end
end
