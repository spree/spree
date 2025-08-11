FactoryBot.define do
  factory :policy, class: 'Spree::Policy' do
    store { Spree::Store.default }
    slug { 'privacy-policy' }
    name { 'Privacy Policy' }
    show_in_checkout_footer { true }
    body { 'This is the privacy policy' }
  end
end
