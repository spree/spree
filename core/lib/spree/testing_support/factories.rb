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
  sequence(:random_string) { FFaker::Lorem.sentence }
  sequence(:random_description) { FFaker::Lorem.paragraphs(1 + Kernel.rand(5)).join("\n") }
  sequence(:random_email) { FFaker::Internet.email }

  sequence(:sku) { |n| "SKU-#{n}" }
end
