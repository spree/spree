module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :webhooks_subscribers, :integrations

    def store=(store)
      super
      self.webhooks_subscribers = store.active_webhooks_subscribers
      self.integrations = store.integrations.active
    end
  end
end
