module Spree
  module Webhooks
    def self.disable_webhooks
      prev_value = disabled?
      RequestStore.store[:disable_spree_webhooks] = true
      yield
    ensure
      RequestStore.store[:disable_spree_webhooks] = prev_value
    end

    def self.disabled?
      # rubocop:disable Style/RedundantFetchBlock
      RequestStore.fetch(:disable_spree_webhooks) { false }
      # rubocop:enable Style/RedundantFetchBlock
    end

    def self.disabled=(value)
      RequestStore.store[:disable_spree_webhooks] = value
    end
  end
end
