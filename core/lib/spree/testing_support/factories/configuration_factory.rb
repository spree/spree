FactoryGirl.define do
  factory :configuration, :class => Spree::Configuration do
    name 'Default Configuration'
    type 'app_configuration'
  end
end
