require 'spree/core'
require 'spree/api'
require 'spree/admin'

module Spree
  module LegacyWebhooks
    def self.disable_webhooks
      prev_value = disabled?
      RequestStore.store[:disable_spree_legacy_webhooks] = true
      yield
    ensure
      RequestStore.store[:disable_spree_legacy_webhooks] = prev_value
    end

    def self.disabled?
      RequestStore.fetch(:disable_spree_legacy_webhooks) { false }
    end

    def self.disabled=(value)
      RequestStore.store[:disable_spree_legacy_webhooks] = value
    end
  end
end

require 'spree/legacy_webhooks/engine'
