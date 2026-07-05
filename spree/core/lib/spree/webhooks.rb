module Spree
  module Webhooks
    def self.disable_webhooks
      Spree::Deprecation.warn('Spree::Webhooks.disable_webhooks is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disable_webhooks instead.')
      prev_value = disabled?
      Thread.current[:disable_spree_legacy_webhooks] = true
      yield
    ensure
      Thread.current[:disable_spree_legacy_webhooks] = prev_value
    end

    def self.disabled?
      Spree::Deprecation.warn('Spree::Webhooks.disabled? is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disabled? instead.')
      !!Thread.current[:disable_spree_legacy_webhooks]
    end

    def self.disabled=(value)
      Spree::Deprecation.warn('Spree::Webhooks.disabled= is deprecated and will be removed in Spree 5.5. Use Spree::LegacyWebhooks.disabled= instead.')
      Thread.current[:disable_spree_legacy_webhooks] = value
    end
  end
end
