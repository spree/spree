# Loaded as one of the dummy application's own config/initializers files by
# spec/fixtures/registry_boot/boot.rb: registers into every Spree registry at
# the top level of the file, the way the guides show it.
RegistryBoot::ARRAY_REGISTRIES.each { |path| RegistryBoot.registry(path) << ApplicationProbe }

Spree.tracking_carriers['probe'] = { name: 'Probe', url: 'https://probe.test/:tracking' }
Spree.tracking_carriers['ups'] = { name: 'Custom UPS', url: 'https://ups.test/:tracking' }
Spree.analytics.events[:probe_viewed] = 'Probe Viewed'

Spree.password_validator = ApplicationProbe
Spree.default_tax_provider = ApplicationProbe
Spree.default_payout_provider = ApplicationProbe

Spree.validators.addresses.register(ApplicationProbe)

# Classes under app/ cannot be loaded until initializer files have run;
# to_prepare runs before after_initialize at boot.
Rails.application.config.to_prepare do
  Spree.validators.addresses.unregister(Spree::Addresses::PhoneValidator)
end

Spree.store_authentication_strategies.add(:probe, ApplicationProbe)
Spree.admin_authentication_strategies.add(:email, ApplicationProbe)
Spree.seller_authentication_strategies.remove(:email)

Rails.application.config.after_initialize do
  RegistryBoot::ARRAY_REGISTRIES.each { |path| RegistryBoot.registry(path) << AfterInitializeProbe }
end
