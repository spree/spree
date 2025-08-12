FactoryBot.define do
  factory :policy, class: 'Spree::Policy' do
    store { Spree::Store.default }
    slug { 'my-policy' }
    name { 'My Policy' }
    show_in_checkout_footer { true }
    body { 'This is the my policy' }
  end
end
