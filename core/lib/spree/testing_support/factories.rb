require 'factory_girl'
require 'pathname'

module SpreeSpec
  module Zone
    def self.global
      Spree::Zone.find_by(name: 'GlobalZone') || FactoryGirl.create(:global_zone)
    end
  end
end

Pathname
  .glob(Pathname.new(__dir__).join('factories/**'))
  .sort
  .each { |path| require("spree/testing_support/factories/#{path.basename}") }

FactoryGirl.define do
  sequence(:random_string)      { FFaker::Lorem.sentence }
  sequence(:random_description) { FFaker::Lorem.paragraphs(1 + Kernel.rand(5)).join("\n") }
  sequence(:random_email)       { FFaker::Internet.email }

  sequence(:sku) { |n| "SKU-#{n}" }
end
