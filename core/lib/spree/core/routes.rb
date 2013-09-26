module Spree
  module Core
    class Engine < ::Rails::Engine
      def self.add_routes(&block)
        @spree_routes ||= []
        @spree_routes << block
      end

      def self.append_routes(&block)
        @append_routes ||= []
        @append_routes << block
      end

      def self.draw_routes(&block)
        @spree_routes ||= []
        @append_routes ||= []
        eval_block(block) if block_given?
        @spree_routes.each { |r| eval_block(&r) }
        @append_routes.each { |r| eval_block(&r) }
      end

      private

        def eval_block(&block)
          Spree::Core::Engine.routes.eval_block(block)
        end
    end
  end
end