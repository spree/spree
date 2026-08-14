require 'spree/core'
require 'pagy'
require 'alba'
require 'oj'
require 'typelizer'
require 'typelizer/proc_resource_resolution'

module Spree
  module Api
  end

  # API dependencies accessor for cleaner access to API dependencies
  #
  # @example Getting a dependency (returns resolved class)
  #   Spree.api.product_serializer.render(product)
  #
  # @example Setting a dependency
  #   Spree.api.product_serializer = MyApp::ProductSerializer
  #
  # @return [Spree::ApiDependenciesAccessor] the API dependencies accessor
  def self.api
    @api_accessor ||= ApiDependenciesAccessor.new
  end

  class ApiDependenciesAccessor
    def method_missing(method_name, *args, &block)
      base_name = method_name.to_s.chomp('=').to_sym

      return super unless api_dependency?(base_name)

      if method_name.to_s.end_with?('=')
        Spree::Api::Dependencies.send(method_name, args.first)
      else
        # Returns resolved class
        Spree::Api::Dependencies.send("#{method_name}_class")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      base_name = method_name.to_s.chomp('=').to_sym
      api_dependency?(base_name) || super
    end

    # Direct access to raw dependencies object for backwards compatibility
    def dependencies
      Spree::Api::Dependencies
    end

    private

    def api_dependency?(name)
      return false unless defined?(Spree::Api::Dependencies)

      dependencies = Spree::Api::Dependencies.class

      # Check V3, dynamically added V2, and the pre-rename names that forward
      # to their replacement for one release.
      dependencies::INJECTION_POINTS.include?(name) ||
        (dependencies.const_defined?(:LEGACY_SERIALIZER_KEYS) &&
          dependencies::LEGACY_SERIALIZER_KEYS.key?(name))
    end
  end
end

require 'spree/api/engine'
