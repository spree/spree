require 'factory_bot'
require 'spree/testing_support/country_pool'

Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  load File.expand_path(f)
end

FactoryBot.define do
  sequence(:random_string) { FFaker::Lorem.sentence }
  sequence(:random_description) { FFaker::Lorem.paragraphs(Kernel.rand(1..5)).join("\n") }
  sequence(:random_email) { FFaker::Internet.email }

  sequence(:sku) { |n| "SKU-#{n}" }
end
