module Spree
  module Promo
    class Environment
      include EnvironmentExtension

      attr_accessor :rules, :actions
    end
  end
end
