module Spree
  module Webhooks
    class Event < Spree::Base
      self.table_name = 'spree_webhooks_events'
    end
  end
end
