# The following options can be changed by creating an initializer in config/initializers/jrails.rb

# jRails uses jQuery.noConflict() by default
# to use the default jQuery varibale, use:
# ActionView::Helpers::PrototypeHelper::JQUERY_VAR = '$'

# ActionView::Helpers::PrototypeHelper:: DISABLE_JQUERY_FORGERY_PROTECTION
# Set this to disable forgery protection in ajax calls
# This is handy if you want to use caching with ajax by injecting the forgery token via another means
# for an example, see http://henrik.nyh.se/2008/05/rails-authenticity-token-with-jquery
# ActionView::Helpers::PrototypeHelper::DISABLE_JQUERY_FORGERY_PROTECTION = true

ActionView::Helpers::AssetTagHelper::JAVASCRIPT_DEFAULT_SOURCES = ['jquery','jquery-ui','jrails']
ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
require 'jrails'
