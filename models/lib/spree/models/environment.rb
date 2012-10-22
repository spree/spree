module Spree
  module Models
    class Environment
      include EnvironmentExtension

      attr_accessor :calculators, :payment_methods, :preferences

      def initialize
        @calculators = Calculators.new
        @preferences = Spree::AppConfiguration.new
      end
    end
  end
end
