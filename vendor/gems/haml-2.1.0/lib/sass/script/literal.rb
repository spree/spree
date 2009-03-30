class Sass::Script::Literal # :nodoc:
  require 'sass/script/string'
  require 'sass/script/number'
  require 'sass/script/color'
  require 'sass/script/bool'

  attr_reader :value

  def initialize(value = nil)
    @value = value
  end

  def perform(environment)
    self
  end

  def and(other)
    to_bool ? other : self
  end

  def or(other)
    to_bool ? self : other
  end

  def eq(other)
    Sass::Script::Bool.new(self.class == other.class && self.value == other.value)
  end

  def neq(other)
    Sass::Script::Bool.new(!eq(other).to_bool)
  end

  def unary_not
    Sass::Script::Bool.new(!to_bool)
  end

  def concat(other)
    Sass::Script::String.new("#{self.to_s} #{other.to_s}")
  end

  def comma(other)
    Sass::Script::String.new("#{self.to_s}, #{other.to_s}")
  end

  def inspect
    value.inspect
  end

  def to_bool
    true
  end

  def ==(other)
    eq(other).to_bool
  end

  def to_i
    raise Sass::SyntaxError.new("#{self.inspect} is not an integer.")
  end
end
