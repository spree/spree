module Spree
  module Webhooks
    class Endpoint < Spree::Base
      self.table_name = 'spree_webhooks_endpoints'
    end
  end
end
