module Spree
  class Environment
    class Calculators
      include EnvironmentExtension

      attr_accessor :shipping_methods, :tax_rates
    end
  end
end

