module Spree
  module Core
    class Engine < ::Rails::Engine
      def self.prepend_routes(&block)
        @spree_prepend ||= []
        @spree_prepend << block
      end

      def self.append_routes(&block)
        @spree_append ||= []
        @spree_append << block
      end

      def self.final_routes(&block)
        @spree_final ||= []
        @spree_final << block
      end

      def self.draw_routes(&block)
        @spree_prepend ||= []
        @spree_append ||= []
        @spree_prepend.each { |r| eval_block(&r) }
        eval_block(block) if block_given?
        @spree_append.each { |r| eval_block(&r) }
        @spree_final.each { |r| eval_block(&r) }
      end

      private

        def eval_block(&block)
          Spree::Core::Engine.routes.eval_block(block)
        end
    end
  end
end