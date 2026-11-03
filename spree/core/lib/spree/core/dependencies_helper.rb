module Spree
  class DependencyError < StandardError; end

  module DependenciesHelper
    # Patterns to skip when finding the actual caller (internal routing code)
    INTERNAL_CALLER_PATTERNS = [
      %r{lib/spree/core\.rb.*method_missing},
      %r{lib/spree/api\.rb.*method_missing}
    ].freeze

    def self.included(base)
      injection_points = base::INJECTION_POINTS_WITH_DEFAULTS.keys.freeze
      base.const_set(:INJECTION_POINTS, injection_points)

      injection_points.each { |point| define_injection_point(base, point) }
    end

    # Defines the reader, the tracked setter and the resolving `_class` reader
    # for one injection point, on a class (core points) or on one instance's
    # singleton class (points an extension registers).
    def self.define_injection_point(target, point)
      # Original getter - returns raw value (string, class, or proc result)
      # BACKWARDS COMPATIBLE: Spree::Dependencies.foo.constantize still works
      target.attr_reader(point)

      # Setter with override tracking
      # BACKWARDS COMPATIBLE: Spree::Dependencies.foo = "MyClass" still works
      target.define_method("#{point}=") do |value|
        @overrides ||= {}
        @overrides[point] = {
          value: value,
          source: find_caller_source,
          set_at: Time.current
        }
        # Clear memoized class when value changes
        remove_instance_variable("@#{point}_resolved") if instance_variable_defined?("@#{point}_resolved")
        instance_variable_set("@#{point}", value)
      end

      # Returns resolved class with memoization
      # Usage: Spree::Dependencies.foo_class or Spree.foo
      target.define_method("#{point}_class") do
        return instance_variable_get("@#{point}_resolved") if instance_variable_defined?("@#{point}_resolved")

        value = send(point)
        resolved = case value
                   when String then value.constantize
                   when Proc then value.call.then { |v| v.is_a?(String) ? v.constantize : v }
                   else value
                   end
        # An injection point may legitimately have no default — the class is
        # supplied by an optional gem (search_product_presenter). Leave it
        # unmemoized so installing the gem later still takes effect.
        return nil if resolved.nil?
        instance_variable_set("@#{point}_resolved", resolved)
        resolved
      end
    end

    def initialize
      set_default_values
    end

    # Adds an injection point an extension owns, so its own workflows and
    # services can be swapped by a host app and exposed to agents exactly
    # like core's:
    #
    #   Spree::Dependencies.register(:quote_send_workflow, 'MyExtension::Quotes::Send')
    #   Spree.quote_send_workflow # => MyExtension::Quotes::Send
    #
    # Register from an initializer. A host app that sets the key afterwards
    # replaces the default, as with any core key. Registering a key that
    # already exists raises, so two gems cannot silently claim one name.
    #
    # @param point [Symbol, String]
    # @param default [String, Class, Proc] class name preferred, so the
    #   class loads on first use
    # @return [Symbol] the key
    def register(point, default)
      point = point.to_sym
      raise ArgumentError, "#{point} is already a dependency" if injection_point?(point)
      # `cart_add_item_workflow_class` would shadow the resolving reader core
      # defines for `cart_add_item_workflow`, and a key `Spree` already
      # answers itself (`search_provider`) would never be read.
      if [self, Spree].any? { |owner| owner.respond_to?(point, true) || owner.respond_to?("#{point}_class", true) }
        raise ArgumentError, "#{point} would replace an existing method"
      end

      # Evaluated first, so a default that raises leaves nothing registered.
      value = default.respond_to?(:call) ? default.call : default
      registered_points[point] = default
      Spree::DependenciesHelper.define_injection_point(singleton_class, point)
      instance_variable_set("@#{point}", value)
      point
    end

    # Core's injection points plus the ones extensions registered.
    #
    # @return [Array<Symbol>]
    def injection_points
      self.class::INJECTION_POINTS + registered_points.keys
    end

    # @param point [Symbol, String]
    # @return [Boolean]
    def injection_point?(point)
      injection_points.include?(point.to_sym)
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
      injection_points.map do |point|
        default = self.class::INJECTION_POINTS_WITH_DEFAULTS.fetch(point) { registered_points[point] }
        default_val = default.respond_to?(:call) ? default.call : default
        current = send(point)

        {
          name: point,
          current: current,
          default: default_val,
          # Use overridden? to check if setter was called, not value comparison
          # Value comparison fails for proc-based defaults that reference other dependencies
          overridden: overridden?(point),
          override_info: overrides[point]
        }
      end
    end

    # Validate all dependencies can be resolved to classes
    # Raises Spree::DependencyError if any dependency is invalid
    def validate!
      errors = []
      injection_points.each do |point|
        send("#{point}_class")
      rescue NameError => e
        errors << { name: point, value: send(point), error: e.message }
      end
      raise Spree::DependencyError, "Invalid dependencies: #{errors.map { |e| e[:name] }.join(', ')}" if errors.any?

      true
    end

    private

    def registered_points
      @registered_points ||= {}
    end

    def set_default_values
      self.class::INJECTION_POINTS_WITH_DEFAULTS.each do |injection_point, default_value|
        value = default_value.respond_to?(:call) ? default_value.call : default_value
        instance_variable_set("@#{injection_point}", value)
      end
    end

    # Find the actual caller source, skipping internal DSL routing code
    # This ensures Spree.foo = X reports the user's code location, not method_missing
    def find_caller_source
      caller_locations(2, 10).each do |location|
        location_str = location.to_s
        next if INTERNAL_CALLER_PATTERNS.any? { |pattern| location_str.match?(pattern) }

        return location_str
      end
      # Fallback to immediate caller if no external caller found
      caller_locations(2, 1).first.to_s
    end
  end
end
