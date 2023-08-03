module Spree
  module DependenciesHelper
    def self.included(base)
      injection_points = base::INJECTION_POINTS_WITH_DEFAULTS.keys.freeze
      base.const_set(:INJECTION_POINTS, injection_points)
      base.attr_accessor(*injection_points)
    end

    def initialize
      set_default_values
    end

    def current_values
      values = []
      self.class::INJECTION_POINTS.each do |injection_point|
        values << { injection_point.to_s => instance_variable_get("@#{injection_point}") }
      end
      values
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
