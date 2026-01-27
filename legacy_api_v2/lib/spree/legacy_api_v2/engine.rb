require 'rails/engine'

module Spree
  module LegacyApiV2
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_legacy_api_v2'

      # Merge V2 dependencies into Spree::Api::Dependencies for backward compatibility
      # This allows existing code using Spree.api.storefront_cart_serializer to continue working
      # initializer 'spree.legacy_api_v2.merge_dependencies', after: 'spree.api.environment' do
      #   Engine.merge_v2_dependencies_into_api!
      # end

      initializer 'spree.legacy_api_v2.checking_migrations' do
        Migrations.new(config, engine_name).check unless Rails.env.test?
      end

      class << self
        def merge_v2_dependencies_into_api!
          api_deps_class = Spree::Api::ApiDependencies
          v2_defaults = Spree::LegacyApiV2::ApiDependencies::INJECTION_POINTS_WITH_DEFAULTS

          # Collect all new V2 points that don't exist in V3
          new_points = []

          v2_defaults.each do |point, default_value|
            # Skip if already defined (V3 has priority)
            next if api_deps_class::INJECTION_POINTS.include?(point)

            new_points << point

            # Define getter
            api_deps_class.attr_reader(point)

            # Define setter with override tracking
            api_deps_class.define_method("#{point}=") do |value|
              @overrides ||= {}
              @overrides[point] = {
                value: value,
                source: find_caller_source,
                set_at: Time.current
              }
              remove_instance_variable("@#{point}_resolved") if instance_variable_defined?("@#{point}_resolved")
              instance_variable_set("@#{point}", value)
            end

            # Define _class method for resolved class access
            api_deps_class.define_method("#{point}_class") do
              return instance_variable_get("@#{point}_resolved") if instance_variable_defined?("@#{point}_resolved")

              value = send(point)
              resolved = case value
                         when String then value.constantize
                         when Proc then value.call.then { |v| v.is_a?(String) ? v.constantize : v }
                         else value
                         end
              instance_variable_set("@#{point}_resolved", resolved)
              resolved
            end

            # Set the default value on the existing Dependencies instance
            value = default_value.respond_to?(:call) ? default_value.call : default_value
            Spree::Api::Dependencies.instance_variable_set("@#{point}", value)
          end

          # Update INJECTION_POINTS constant with all new points at once
          if new_points.any?
            combined_points = (api_deps_class::INJECTION_POINTS.to_a + new_points).freeze
            api_deps_class.send(:remove_const, :INJECTION_POINTS)
            api_deps_class.const_set(:INJECTION_POINTS, combined_points)
          end
        end
      end
    end
  end
end
