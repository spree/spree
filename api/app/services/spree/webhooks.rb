module Spree
  module Webhooks
    def self.disable_webhooks(&block)
      webhooks_disabled_previously = ENV['DISABLE_SPREE_WEBHOOKS']
      begin
        ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
        block.call
      ensure
        ENV['DISABLE_SPREE_WEBHOOKS'] = webhooks_disabled_previously
      end
    end
  end
end
