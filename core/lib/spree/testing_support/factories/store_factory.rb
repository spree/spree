FactoryBot.define do
  factory :store, class: Spree::Store do
    sequence(:code)        { |i| "spree_#{i}" }
    name                   { 'Spree Test Store' }
    url                    { 'www.example.com' }
    mail_from_address      { 'no-reply@example.com' }
    customer_support_email { 'support@example.com' }
    default_currency       { 'USD' }
    facebook               { 'spreecommerce' }
    twitter                { 'spreecommerce' }
    instagram              { 'spreecommerce' }
  end
end
