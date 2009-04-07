require 'sass/tree/node'

module Sass::Tree
  class WhileNode < Node
    def initialize(expr, options)
      @expr = expr
      super(options)
    end

    private

    def _perform(environment)
      children = []
      while @expr.perform(environment).to_bool
        children += perform_children(Sass::Environment.new(environment))
      end
      children
    end
  end
end
