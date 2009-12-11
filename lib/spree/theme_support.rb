require_dependency 'spree/theme_support/hook'
require 'spree/theme_support/more_patches'

ActionController::Base.class_eval do
  include Spree::ThemeSupport::HookHelper
end
