require 'friendly_id/paranoia'
require 'mobility/plugins/store_based_fallbacks'
if Rails::VERSION::STRING >= '7.1.0'
  require 'ransack/context_decorator'
end

require 'spree/core'
