module Sass::Script
  class UnaryOperation # :nodoc:
    def initialize(operand, operator)
      @operand = operand
      @operator = operator
    end

    def inspect
      "(#{@operator.inspect} #{@operand.inspect})"
    end

    def perform(environment)
      operator = "unary_#{@operator}"
      literal = @operand.perform(environment)
      literal.send(operator)
    rescue NoMethodError => e
      raise e unless e.name.to_s == operator.to_s
      raise Sass::SyntaxError.new("Undefined unary operation: \"#{@operator} #{literal}\".")
    end
  end
end
