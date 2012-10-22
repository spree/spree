module Spree
  module Models
    class Environment
      class Calculators
        include EnvironmentExtension

        attr_accessor :shipping_methods, :tax_rates
      end
    end
  end
end

