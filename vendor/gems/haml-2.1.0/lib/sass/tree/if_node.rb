require 'sass/tree/node'

module Sass::Tree
  class IfNode < Node
    attr_accessor :else

    def initialize(expr, options)
      @expr = expr
      @last_else = self
      super(options)
    end

    def add_else(node)
      @last_else.else = node
      @last_else = node
    end

    protected

    def _perform(environment)
      environment = Sass::Environment.new(environment)
      return perform_children(environment) if @expr.nil? || @expr.perform(environment).to_bool
      return @else.perform(environment) if @else
      []
    end
  end
end
