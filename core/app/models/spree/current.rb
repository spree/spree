module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :webhooks_subscribers

    def store
      super || Spree::Store.default
    end

    def webhooks_subscribers
      super || store&.active_webhooks_subscribers || Spree::Webhooks::Subscriber.none
    end
  end
end
