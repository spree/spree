module Spree::ThemeSupport::HookHelper
  
  # Allow hooks to be used in views like this:
  # 
  #   <%= call_hook(:some_hook) %>
  #   <%= call_hook(:another_hook, :foo => 'bar' %>
  # 
  # Or in controllers like:
  #   call_hook(:some_hook)
  #   call_hook(:another_hook, :foo => 'bar')
  # 
  # Hooks added to views will be concatenated into a string.  Hooks added to
  # controllers will return an array of results.
  #
  # Several objects are automatically added to the call context:
  # 
  # * request => Request instance
  # * controller => current Controller instance
  # 
  def call_hook(hook, context={})
    if is_a?(ActionController::Base)
      default_context = {:controller => self, :request => request}
      Spree::ThemeSupport::Hook.call_hook(hook, default_context.merge(context))
    else
      default_context = {:controller => controller, :request => request}
      Spree::ThemeSupport::Hook.call_hook(hook, default_context.merge(context)).join(' ')
    end        
  end

  def self.included(base)
    base.helper_method :call_hook
  end

end