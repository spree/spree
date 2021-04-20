FactoryBot.define do
  factory :menu_item, class: Spree::MenuItem do
    name { 'Link To Somewhere' }
    item_type { 'Link' }
    subtitle { 'Some Descriptive Text!' }
    linked_resource_type { 'URL' }
    url { 'https://test.spree.com' }
  end
end
