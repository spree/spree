# frozen_string_literal: true

require 'concurrent'
require 'mobility'

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
