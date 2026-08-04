module Spree
  module Core
    class Engine < ::Rails::Engine
      def self.add_routes(&block)
        @spree_routes ||= []

        # Anything that causes the application's routes to be reloaded will cause
        # this method to be called more than once (in some setups only in the
        # production env). Coupled with Rails' insistence that routes are not
        # drawn twice, that poses quite a serious problem.
        #
        # This is mainly why this whole file exists in the first place.
        #
        # Thus we need to make sure that the routes aren't drawn twice.
        @spree_routes << block unless @spree_routes.include?(block)
      end

      def self.append_routes(&block)
        @append_routes ||= []
        # See comment in add_routes.
        @append_routes << block unless @append_routes.include?(block)
      end

      def self.draw_routes(&block)
        @spree_routes ||= []
        @append_routes ||= []
        eval_block(block) if block_given?
        @spree_routes.each { |r| eval_block(&r) }
        @append_routes.each { |r| eval_block(&r) }
        # # Clear out routes so that they aren't drawn twice.
        @spree_routes = []
        @append_routes = []
      end

      def eval_block(&block)
        Spree::Core::Engine.routes.send :eval_block, block
      end
    end
  end
end
