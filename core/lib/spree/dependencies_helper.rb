module Spree
  module DependenciesHelper
    def current_values
      values = []
      self.class::INJECTION_POINTS.each do |injection_point|
        values << { injection_point.to_s => instance_variable_get("@#{injection_point}") }
      end
      values
    end
  end
end
