FactoryGirl.define do
  factory :taxon, class: Spree::Taxon do
    name 'Ruby on Rails'
    taxonomy
    parent_id nil
  end
end
