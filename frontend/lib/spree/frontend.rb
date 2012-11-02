require 'rails/all'
require 'rails/generators'
require 'jquery-rails'
require 'deface'
require 'select2-rails'
require 'rabl'

require 'spree/core'

require 'spree/core/delegate_belongs_to'

require 'spree/core/responder'
require 'spree/core/ssl_requirement'
require 'spree/core/store_helpers'
require 'spree/core/mail_settings'
require 'spree/core/mail_interceptor'

require 'spree/frontend/responder'
require 'spree/frontend/store_helpers'
require 'spree/frontend/middleware/seo_assist'

require 'spree/frontend/engine'

if defined?(ActionView)
  require 'awesome_nested_set/helper'
  ActionView::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet::Helper
  end
end

ActiveSupport.on_load(:action_view) do
  include Spree::Core::StoreHelpers
end
