module Sass::Script
  # Methods in this module are accessible from the Sass script context.
  # For example, you can write
  #
  #   color = hsl(120, 100%, 50%)
  #
  # and it will call Sass::Script::Functions#hsl.
  #
  # You can add your own functions to this module,
  # but there are a few things to keep in mind.
  # First of all, the arguments passed are (currently undocumented) Sass::Script::Literal objects,
  # Literal objects are also the expected return values.
  #
  # Second, making Ruby functions accessible from Sass introduces the temptation
  # to do things like database access within stylesheets.
  # This temptation must be resisted.
  # Keep in mind that Sass stylesheets are only compiled once
  # at a somewhat indeterminate time
  # and then left as static CSS files.
  # Any dynamic CSS should be left in <style> tags in the HTML.
  #
  # The following functions are provided:
  # * +hsl+ - converts an <tt>hsl(hue, saturation, lightness)</tt> triplet into a color.
  #
  #   The +hue+ value should be between 0 and 360 inclusive,
  #   saturation and lightness must be between <tt>0%</tt> to <tt>100%</tt> inclusive.
  #   The percent sign is optional.
  # * +percentage+ - converts a unitless number to a css percentage.
  #
  #   Example: <tt>percentage(14px / 7px) => 200%</tt>
  # * +round+ - Rounds a number to the nearest whole number.
  #
  #   Example: <tt>round(10.4px) => 10px</tt>
  # * +ceil+ - Rounds a number up to the nearest whole number.
  #
  #   Example: <tt>ceil(10.4px) => 11px</tt>
  # * +floor+ - Rounds a number down to the nearest whole number.
  #
  #   Example: <tt>floor(10.6px) => 10px</tt>
  # * +abs+ - Returns the absolute value of a number.
  #
  #   Example: <tt>abs(-10px) => 10px</tt>
  module Functions
    instance_methods.each { |m| undef_method m unless m.to_s =~ /^__/ }
    extend self

    # Creates a Sass::Script::Color object from hue, saturation, and lightness.
    # As per the CSS3 spec (http://www.w3.org/TR/css3-color/#hsl-color),
    # hue is in degrees,
    # and saturation and lightness are percentages.
    def hsl(h, s, l)
      original_s = s
      original_l = l
      # This algorithm is from http://www.w3.org/TR/css3-color#hsl-color
      h, s, l = [h, s, l].map { |a| a.value }
      raise ArgumentError.new("Saturation #{s} must be between 0% and 100%") if s < 0 || s > 100
      raise ArgumentError.new("Lightness #{l} must be between 0% and 100%") if l < 0 || l > 100

      h = (h % 360) / 360.0
      s /= 100.0
      l /= 100.0

      m2 = l <= 0.5 ? l * (s + 1) : l + s - l * s
      m1 = l * 2 - m2
      Color.new([hue_to_rgb(m1, m2, h + 1.0/3),
                 hue_to_rgb(m1, m2, h),
                 hue_to_rgb(m1, m2, h - 1.0/3)].map { |c| (c * 0xff).round })
    end

    # Converts a unitless number into a percent and multiplies the number by 100.
    # E.g. percentage(100px / 50px) => 200%
    # Some may find this more natural than: 100% * 100px / 50px
    def percentage(value)
      unless value.is_a?(Sass::Script::Number) && value.unitless?
        raise ArgumentError.new("#{value} is not a unitless number")
      end
      Sass::Script::Number.new(value.value * 100, ['%'])
    end

    # Rounds a number to the nearest whole number.
    def round(value)
      numeric_transformation(value) {|n| n.round}
    end

    # Rounds up to the nearest whole number.
    def ceil(value)
      numeric_transformation(value) {|n| n.ceil}
    end

    # Rounds down to the nearest whole number.
    def floor(value)
      numeric_transformation(value) {|n| n.floor}
    end

    # Returns the absolute value of a number.
    def abs(value)
      numeric_transformation(value) {|n| n.abs}
    end

    private

    # This method implements the pattern of transforming a numeric value into
    # another numeric value with the same units.
    # It yields a number to a block to perform the operation and return a number
    def numeric_transformation(value)
      unless value.is_a?(Sass::Script::Number)
        calling_function = caller.first.scan(/`([^']+)'/).first.first
        raise Sass::SyntaxError.new("#{value} is not a number for `#{calling_function}'")
      end
      Sass::Script::Number.new(yield(value.value), value.numerator_units, value.denominator_units)
    end

    def hue_to_rgb(m1, m2, h)
      h += 1 if h < 0
      h -= 1 if h > 1
      return m1 + (m2 - m1) * h * 6 if h * 6 < 1
      return m2 if h * 2 < 1
      return m1 + (m2 - m1) * (2.0/3 - h) * 6 if h * 3 < 2
      return m1
    end
  end
end
