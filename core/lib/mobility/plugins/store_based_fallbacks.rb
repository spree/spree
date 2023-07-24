# frozen_string_literal: true

require 'concurrent'
require 'mobility'

# The default implementation in the Mobility gem requires fallbacks to be defined when booting the application.
# This patch allows to dynamically reconfigure translations fallbacks, by setting Mobility.store_based_fallbacks attribute.
# The implementation is based on the default fallbacks plugin, with some changes around fetching the list of fallbacks to be used.
# https://github.com/shioyama/mobility/blob/master/lib/mobility/plugins/fallbacks.rb
module Mobility
  @store_based_fallbacks = Concurrent::ThreadLocalVar.new(I18n::Locale::Fallbacks.new)

  class << self
    def store_based_fallbacks
      @store_based_fallbacks.value
    end

    def store_based_fallbacks=(value)
      @store_based_fallbacks.value = value
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
