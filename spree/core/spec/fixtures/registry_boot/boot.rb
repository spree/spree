# Boots the dummy application in a fresh process, with probe classes
# registered into every Spree registry from an extension engine's
# initializer, an application initializer file and an after_initialize
# block, then prints what each registry ended up holding as JSON.
#
#   ruby boot.rb <path to dummy app>
ENV['RAILS_ENV'] = 'test'
require File.expand_path('config/application', ARGV.fetch(0))
require 'json'
require_relative 'registries'

class RegistryProbe
  def self.key
    name.underscore
  end
end
ExtensionProbe = Class.new(RegistryProbe)
ApplicationProbe = Class.new(RegistryProbe)
AfterInitializeProbe = Class.new(RegistryProbe)

module RegistryBootExtension
  class Engine < Rails::Engine
    initializer 'registry_boot.register_probes' do
      RegistryBoot::ARRAY_REGISTRIES.each { |path| RegistryBoot.registry(path) << ExtensionProbe }
    end
  end
end

Rails.application.config.paths['config/initializers'] << File.expand_path('initializers', __dir__)
Rails.application.initialize!

puts JSON.generate(
  RegistryBoot::ARRAY_REGISTRIES.to_h { |path| [path, RegistryBoot.names(RegistryBoot.registry(path))] }.merge(
    'tracking_carriers' => Spree.tracking_carriers.keys,
    'tracking_carriers.ups' => Spree.tracking_carriers['ups'][:name],
    'analytics.events' => Spree.analytics.events.keys.map(&:to_s),
    'password_validator' => Spree.password_validator.name,
    'default_tax_provider' => Spree.default_tax_provider.name,
    'default_payout_provider' => Spree.default_payout_provider.name,
    'validators.addresses' => RegistryBoot.names(Spree.validators.addresses),
    'store_authentication_strategies' => Spree.store_authentication_strategies.keys.map(&:to_s),
    'admin_authentication_strategies.email' => Spree.admin_authentication_strategies[:email].name,
    'seller_authentication_strategies' => Spree.seller_authentication_strategies.keys.map(&:to_s)
  )
)
