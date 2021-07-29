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

    trait :with_favicon do
      transient do
        filepath { Spree::Core::Engine.root.join('spec', 'fixtures', 'favicon.ico') }
        image_type { 'image/x-icon' }
      end

      favicon_image do
        Rack::Test::UploadedFile.new(filepath, image_type)
      end
    end
  end
end
