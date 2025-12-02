module Spree
  class DependencyError < StandardError; end

  module DependenciesHelper
    def self.included(base)
      injection_points = base::INJECTION_POINTS_WITH_DEFAULTS.keys.freeze
      base.const_set(:INJECTION_POINTS, injection_points)

      injection_points.each do |point|
        # Original getter - returns raw value (string, class, or proc result)
        # BACKWARDS COMPATIBLE: Spree::Dependencies.foo.constantize still works
        base.attr_reader(point)

        # Setter with override tracking
        # BACKWARDS COMPATIBLE: Spree::Dependencies.foo = "MyClass" still works
        base.define_method("#{point}=") do |value|
          @overrides ||= {}
          @overrides[point] = {
            value: value,
            source: caller_locations(1, 1).first.to_s,
            set_at: Time.current
          }
          # Clear memoized class when value changes
          remove_instance_variable("@#{point}_resolved") if instance_variable_defined?("@#{point}_resolved")
          instance_variable_set("@#{point}", value)
        end

        # Returns resolved class with memoization
        # Usage: Spree::Dependencies.foo_class or Spree.foo
        base.define_method("#{point}_class") do
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
      end
    end

    def initialize
      set_default_values
    end

    # Returns hash of all overridden dependencies with metadata
    def overrides
      @overrides || {}
    end

    # Check if a specific dependency has been overridden
    def overridden?(name)
      overrides.key?(name.to_sym)
    end

    # Get override info for a specific dependency
    def override_info(name)
      overrides[name.to_sym]
    end

    # Returns array of all dependencies with current values and metadata
    def current_values
      self.class::INJECTION_POINTS.map do |point|
        default = self.class::INJECTION_POINTS_WITH_DEFAULTS[point]
        default_val = default.respond_to?(:call) ? default.call : default
        current = send(point)

        {
          name: point,
          current: current,
          default: default_val,
          overridden: current != default_val,
          override_info: overrides[point]
        }
      end
    end

    # Validate all dependencies can be resolved to classes
    # Raises Spree::DependencyError if any dependency is invalid
    def validate!
      errors = []
      self.class::INJECTION_POINTS.each do |point|
        send("#{point}_class")
      rescue NameError => e
        errors << { name: point, value: send(point), error: e.message }
      end
      raise Spree::DependencyError, "Invalid dependencies: #{errors.map { |e| e[:name] }.join(', ')}" if errors.any?

      true
    end

    private

    def set_default_values
      self.class::INJECTION_POINTS_WITH_DEFAULTS.each do |injection_point, default_value|
        value = default_value.respond_to?(:call) ? default_value.call : default_value
        instance_variable_set("@#{injection_point}", value)
      end
    end
  end
end
