# frozen_string_literal: true

require 'mobility'

# The default implementation in the Mobility gem requires fallbacks to be defined when booting the application.
# This patch allows to dynamically reconfigure translations fallbacks, by setting Mobility.store_based_fallbacks attribute.
# The implementation is based on the default fallbacks plugin, with some changes around fetching the list of fallbacks to be used.
# https://github.com/shioyama/mobility/blob/master/lib/mobility/plugins/fallbacks.rb
module Mobility
  class << self
    # Request-scoped via RequestStore (like Mobility.locale), so one request's
    # store fallbacks can't leak into the next request served by the same
    # thread. Outside a request RequestStore degrades to plain per-thread
    # storage; Spree::BaseMailer#with_store_locale restores the previous value
    # around mail rendering.
    def store_based_fallbacks
      RequestStore.store[:mobility_store_based_fallbacks] ||= I18n::Locale::Fallbacks.new
    end

    def store_based_fallbacks=(value)
      RequestStore.store[:mobility_store_based_fallbacks] = value
    end
  end

  module Plugins
    module StoreBasedFallbacks
      extend ::Mobility::Plugin

      default true
      requires :backend, include: :before

      # Applies fallbacks plugin to attributes. Completely disables fallbacks
      # on model if option is +false+.
      included_hook do |_, backend_class|
        unless options[:fallbacks] == false
          backend_class.include(BackendInstanceMethods)
        end
      end

      module BackendInstanceMethods
        def read(locale, fallback: true, **kwargs)
          return super(locale, **kwargs) if !fallback || kwargs[:locale]

          locales = Mobility.store_based_fallbacks[locale]
          locales.each do |fallback_locale|
            value = super(fallback_locale, **kwargs)
            return value if Util.present?(value)
          end

          super(locale, **kwargs)
        end
      end
    end

    register_plugin(:store_based_fallbacks, StoreBasedFallbacks)
  end
end
