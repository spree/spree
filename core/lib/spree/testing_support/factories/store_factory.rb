FactoryBot.define do
  factory :store, class: Spree::Store do
    sequence(:code)        { |i| "spree_#{i}" }
    name                   { 'Spree Test Store' }
    url                    { 'www.example.com' }
    mail_from_address      { 'no-reply@example.com' }
    customer_support_email { 'support@example.com' }
    new_order_notifications_email { 'store-owner@example.com' }
    default_currency       { 'USD' }
    supported_currencies   { 'USD,EUR,GBP' }
    default_locale         { 'en' }
    facebook               { 'spreecommerce' }
    twitter                { 'spreecommerce' }
    instagram              { 'spreecommerce' }
    meta_description       { 'Sample store description.' }

    trait :with_favicon do
      after(:build) do |store|
        store.favicon_image.attach(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'thinking-cat.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
