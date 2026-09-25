# Every array registry Spree fills at boot, shared by boot.rb and
# spec/lib/spree/core/engine_spec.rb.
module RegistryBoot
  ARRAY_REGISTRIES = %w[
    calculators.shipping_methods
    calculators.tax_rates
    calculators.promotion_actions_create_adjustments
    calculators.promotion_actions_create_item_adjustments
    stock_splitters
    payment_methods
    adjusters
    media_viewable_types
    tax_providers
    pricing_providers
    inventory_providers
    payout_providers
    fulfillment_providers
    delivery_rate_providers
    digital_asset_providers
    delivery_profile_types
    order_routing.strategies
    order_routing.rules
    commission_rules
    seller_requirements
    delivery_method_rules
    promotions.rules
    promotions.actions
    pricing.rules
    data_feed_types
    export_types
    import_types
    taxon_rules
    collection_rules
    time_based_collection_rules
    translatable_resources
    taggable_types
    actor_classes
    custom_fields.types
    custom_fields.enabled_resources
    analytics_event_handlers
    integrations
  ].freeze

  # @param path [String] e.g. 'promotions.rules' for config.spree.promotions.rules
  def self.registry(path)
    path.split('.').reduce(Rails.application.config.spree) { |config, name| config.public_send(name) }
  end

  def self.names(entries)
    entries.map { |entry| entry.is_a?(Module) ? entry.name : entry.to_s }
  end
end
