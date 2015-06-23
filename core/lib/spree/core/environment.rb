module Spree
  module Core
    class Environment
      include EnvironmentExtension

      attr_accessor :calculators, :payment_methods, :preferences,
                    :adjusters, :stock_splitters

      def initialize
        @calculators = Calculators.new
        @preferences = Spree::AppConfiguration.new
      end
    end
  end
end
