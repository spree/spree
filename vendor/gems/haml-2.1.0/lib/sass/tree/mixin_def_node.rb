module Sass
  module Tree
    class MixinDefNode < Node
      def initialize(name, args, options)
        @name = name
        @args = args
        super(options)
      end

      private

      def _perform(environment)
        environment.set_mixin(@name, Sass::Mixin.new(@name, @args, environment, children))
        []
      end
    end
  end
end
