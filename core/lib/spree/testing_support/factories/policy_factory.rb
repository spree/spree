FactoryBot.define do
  factory :policy, class: 'Spree::Policy' do
    owner { Spree::Store.default }
    slug { 'my-policy' }
    name { 'My Policy' }
    body { 'This is the my policy' }
  end
end
