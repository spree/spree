FactoryGirl.define do
  factory :taxon do
    name 'Ruby on Rails'
    taxonomy { Factory(:taxonomy) }
    parent_id nil
  end
end