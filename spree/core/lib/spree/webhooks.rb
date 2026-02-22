module Spree
  module Webhooks
    def self.disable_webhooks
      Spree::Deprecation.warn('Spree::Webhooks.disable_webhooks is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disable_webhooks instead.')
      prev_value = disabled?
      RequestStore.store[:disable_spree_legacy_webhooks] = true
      yield
    ensure
      RequestStore.store[:disable_spree_legacy_webhooks] = prev_value
    end

    def self.disabled?
      Spree::Deprecation.warn('Spree::Webhooks.disabled? is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disabled? instead.')
      RequestStore.fetch(:disable_spree_legacy_webhooks) { false }
    end

    def self.disabled=(value)
      Spree::Deprecation.warn('Spree::Webhooks.disabled= is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disabled= instead.')
      RequestStore.store[:disable_spree_legacy_webhooks] = value
    end
  end
end
