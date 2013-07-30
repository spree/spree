require 'rails/all'
require 'rails/generators'
require 'jquery-rails'
require 'canonical-rails'
require 'deface'

require 'spree/core'

require 'spree/core/mail_settings'
require 'spree/core/mail_interceptor'

require 'spree/responder'
require 'spree/frontend/middleware/seo_assist'

require 'spree/frontend/engine'

if defined?(ActionView)
  require 'awesome_nested_set/helper'
  ActionView::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet::Helper
  end
end
