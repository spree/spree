require 'factory_girl'

Spree::Zone.class_eval do
  def self.global
    find_by(name: 'GlobalZone') || FactoryGirl.create(:global_zone)
  end
end

Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  load File.expand_path(f)
end

FactoryGirl.define do
  sequence(:random_string) { |n| "random_string#{n}" }
  sequence(:random_description) { |n| "random_description-#{n}" }
  sequence(:random_email) { |n| "random-#{n}@email.com" }

  sequence(:sku) { |n| "SKU-#{n}" }
  sequence(:random_code) { SecureRandom.hex(5) }
end
