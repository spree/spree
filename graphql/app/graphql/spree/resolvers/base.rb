module Spree
  module Resolvers
    class Base
      attr_reader :key, :spree_current_user, :spree_current_order

      def initialize(key)
        @key = key
      end

      def self.[](key)
        self.new(key)
      end

      def call(object, arguments, context)
        @spree_current_user = context[:spree_current_user]
        @spree_current_order = context[:spree_current_order]
        send(key, object, arguments, context)
      end

      def authorize?(*args)
        ability = Spree::Dependencies.ability_class.constantize.new(@spree_current_user)
        ability.can?(*args)
      end
    end
  end
end
