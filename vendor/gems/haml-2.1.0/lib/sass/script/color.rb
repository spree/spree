require 'sass/script/literal'

module Sass::Script
  class Color < Literal # :nodoc:
    class << self; include Haml::Util; end

    HTML4_COLORS = map_vals({
        'black'   => 0x000000,
        'silver'  => 0xc0c0c0,
        'gray'    => 0x808080,
        'white'   => 0xffffff,
        'maroon'  => 0x800000,
        'red'     => 0xff0000,
        'purple'  => 0x800080,
        'fuchsia' => 0xff00ff,
        'green'   => 0x008000,
        'lime'    => 0x00ff00,
        'olive'   => 0x808000,
        'yellow'  => 0xffff00,
        'navy'    => 0x000080,
        'blue'    => 0x0000ff,
        'teal'    => 0x008080,
        'aqua'    => 0x00ffff
      }) {|color| (0..2).map {|n| color >> (n << 3) & 0xff}.reverse}
    HTML4_COLORS_REVERSE = map_hash(HTML4_COLORS) {|k, v| [v, k]}

    def initialize(rgb)
      rgb = rgb.map {|c| c.to_i}
      raise Sass::SyntaxError.new("Color values must be between 0 and 255") if rgb.any? {|c| c < 0 || c > 255}
      super(rgb)
    end

    def plus(other)
      if other.is_a? Sass::Script::String
        Sass::Script::String.new(self.to_s + other.to_s)
      else
        piecewise(other, :+)
      end
    end

    def minus(other)
      if other.is_a? Sass::Script::String
        raise NoMethodError.new(nil, :minus)
      else
        piecewise(other, :-)
      end
    end

    def times(other)
      if other.is_a? Sass::Script::String
        raise NoMethodError.new(nil, :times)
      else
        piecewise(other, :*)
      end
    end

    def div(other)
      if other.is_a? Sass::Script::String
        raise NoMethodError.new(nil, :div)
      else
        piecewise(other, :/)
      end
    end

    def mod(other)
      if other.is_a? Sass::Script::String
        raise NoMethodError.new(nil, :mod)
      else
        piecewise(other, :%)
      end
    end

    def to_s
      return HTML4_COLORS_REVERSE[@value] if HTML4_COLORS_REVERSE[@value]
      red, green, blue = @value.map { |num| num.to_s(16).rjust(2, '0') }
      "##{red}#{green}#{blue}"
    end
    alias_method :inspect, :to_s

    private

    def piecewise(other, operation)
      other_num = other.is_a? Number
      other_val = other.value
      if other_num && !other.unitless?
        raise Sass::SyntaxError.new("Cannot add a number with units (#{other}) to a color (#{self}).") 
      end

      rgb = []
      for i in (0...3)
        res = @value[i].send(operation, other_num ? other_val : other_val[i])
        rgb[i] = [ [res, 255].min, 0 ].max
      end
      Color.new(rgb)
    end
  end
end
