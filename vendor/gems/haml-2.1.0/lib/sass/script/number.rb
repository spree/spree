require 'sass/script/literal'

module Sass::Script
  class Number < Literal # :nodoc:

    attr_reader :numerator_units, :denominator_units

    PRECISION = 1000.0

    def initialize(value, numerator_units = [], denominator_units = [])
      super(value)
      @numerator_units = numerator_units
      @denominator_units = denominator_units
      normalize!
    end

    def plus(other)
      if other.is_a? Number
        operate(other, :+)
      elsif other.is_a?(Color)
        other.plus(self)
      else
        Sass::Script::String.new(self.to_s + other.to_s)
      end
    end

    def minus(other)
      if other.is_a? Number
        operate(other, :-)
      else
        raise NoMethodError.new(nil, :minus)
      end
    end

    def unary_minus
      Number.new(-value, numerator_units, denominator_units)
    end

    def times(other)
      if other.is_a? Number
        self.operate(other, :*)
      elsif other.is_a? Color
        other.times(self)
      else
        raise NoMethodError.new(nil, :times)
      end
    end

    def div(other)
      if other.is_a? Number
        operate(other, :/)
      else
        raise NoMethodError.new(nil, :div)
      end
    end

    def mod(other)
      if other.is_a?(Number)
        unless other.unitless?
          raise Sass::SyntaxError.new("Cannot modulo by a number with units: #{other.inspect}.")
        end
        operate(other, :%)
      else
        raise NoMethodError.new(nil, :mod)
      end
    end

    def eq(other)
      Sass::Script::Bool.new(super.to_bool &&
        self.numerator_units.sort == other.numerator_units.sort &&
        self.denominator_units.sort == other.denominator_units.sort)
    end

    def gt(other)
      raise NoMethodError.new(nil, :gt) unless other.is_a?(Number)
      operate(other, :>)
    end

    def gte(other)
      raise NoMethodError.new(nil, :gt) unless other.is_a?(Number)
      operate(other, :>=)
    end

    def lt(other)
      raise NoMethodError.new(nil, :gt) unless other.is_a?(Number)
      operate(other, :<)
    end

    def lte(other)
      raise NoMethodError.new(nil, :gt) unless other.is_a?(Number)
      operate(other, :<=)
    end

    def to_s
      raise Sass::SyntaxError.new("#{inspect} isn't a valid CSS value.") unless legal_units?
      inspect
    end

    def inspect
      value =
        if self.value.is_a?(Float) && (self.value.infinite? || self.value.nan?)
          self.value
        elsif int?
          self.value.to_i
        else
          (self.value * PRECISION).round / PRECISION
        end
      "#{value}#{unit_str}"
    end

    def to_i
      super unless int?
      return value
    end

    def int?
      value % 1 == 0.0
    end

    def unitless?
      numerator_units.empty? && denominator_units.empty?
    end

    def legal_units?
      (numerator_units.empty? || numerator_units.size == 1) && denominator_units.empty?
    end

    protected

    def operate(other, operation)
      this = self
      if [:+, :-].include?(operation)
        if unitless?
          this = this.coerce(other.numerator_units, other.denominator_units)
        else
          other = other.coerce(numerator_units, denominator_units)
        end
      end
      # avoid integer division
      value = (:/ == operation) ? this.value.to_f : this.value
      result = value.send(operation, other.value)

      if result.is_a?(Numeric)
        Number.new(result, *compute_units(this, other, operation))
      else # Boolean op
        Bool.new(result)
      end
    end

    def coerce(num_units, den_units)
      Number.new(if unitless?
                          self.value
                        else
                          self.value * coercion_factor(self.numerator_units, num_units) /
                            coercion_factor(self.denominator_units, den_units)
                        end, num_units, den_units)
    end
    
    def coercion_factor(from_units, to_units)
      # get a list of unmatched units
      from_units, to_units = sans_common_units(from_units, to_units)

      if from_units.size != to_units.size || !convertable?(from_units | to_units)
        raise Sass::SyntaxError.new("Incompatible units: '#{from_units.join('*')}' and '#{to_units.join('*')}'.")
      end

      from_units.zip(to_units).inject(1) {|m,p| m * conversion_factor(p[0], p[1]) }
    end

    def compute_units(this, other, operation)
      case operation
      when :*
        [this.numerator_units + other.numerator_units, this.denominator_units + other.denominator_units]
      when :/
        [this.numerator_units + other.denominator_units, this.denominator_units + other.numerator_units]
      else  
        [this.numerator_units, this.denominator_units]
      end
    end

    def unit_str
      rv = numerator_units.join("*")
      if denominator_units.any?
        rv << "/"
        rv << denominator_units.join("*")
      end
      rv
    end

    def normalize!
      return if unitless?
      @numerator_units, @denominator_units = sans_common_units(numerator_units, denominator_units)

      @denominator_units.each_with_index do |d, i|
        if convertable?(d) && (u = @numerator_units.detect(&method(:convertable?)))
          @value /= conversion_factor(d, u)
          @denominator_units.delete_at(i)
          @numerator_units.delete_at(@numerator_units.index(u))
        end
      end
    end

    # A hash of unit names to their index in the conversion table
    CONVERTABLE_UNITS = {"in" => 0,        "cm" => 1,    "pc" => 2,    "mm" => 3,   "pt" => 4}
    CONVERSION_TABLE = [[ 1,                2.54,         6,            25.4,        72        ], # in
                        [ nil,              1,            2.36220473,   10,          28.3464567], # cm
                        [ nil,              nil,          1,            4.23333333,  12        ], # pc
                        [ nil,              nil,          nil,          1,           2.83464567], # mm
                        [ nil,              nil,          nil,          nil,         1         ]] # pt

    def conversion_factor(from_unit, to_unit)
      res = CONVERSION_TABLE[CONVERTABLE_UNITS[from_unit]][CONVERTABLE_UNITS[to_unit]]
      return 1.0 / conversion_factor(to_unit, from_unit) if res.nil?
      res
    end

    def convertable?(units)
      Array(units).all?(&CONVERTABLE_UNITS.method(:include?))
    end

    def sans_common_units(units1, units2)
      units2 = units2.dup
      # Can't just use -, because we want px*px to coerce properly to px*mm
      return units1.map do |u|
        next u unless j = units2.index(u)
        units2.delete_at(j)
        nil
      end.compact, units2
    end
  end
end
