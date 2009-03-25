require 'sass/script/string'
require 'sass/script/number'
require 'sass/script/color'
require 'sass/script/functions'
require 'sass/script/unary_operation'

module Sass::Script
  class Operation # :nodoc:
    def initialize(operand1, operand2, operator)
      @operand1 = operand1
      @operand2 = operand2
      @operator = operator
    end

    def inspect
      "(#{@operator.inspect} #{@operand1.inspect} #{@operand2.inspect})"
    end

    def perform(environment)
      literal1 = @operand1.perform(environment)
      literal2 = @operand2.perform(environment)
      begin
        literal1.send(@operator, literal2)
      rescue NoMethodError => e
        raise e unless e.name.to_s == @operator.to_s
        raise Sass::SyntaxError.new("Undefined operation: \"#{literal1} #{@operator} #{literal2}\".")
      end
    end
  end
end
