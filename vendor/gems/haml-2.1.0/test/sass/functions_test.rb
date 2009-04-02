require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/sass'
require 'sass/script'

class SassFunctionTest < Test::Unit::TestCase
  def test_hsl
    # These tests adapted from the w3c browser tests
    # http://www.w3.org/Style/CSS/Test/CSS3/Color/20070927/html4/t040204-hsl-h-rotating-b.htm
    red = [255, 0, 0]
    assert_rgb_hsl(red, ['0', '100%', '50%'])
    assert_rgb_hsl(red, ['-360', '100%', '50%'])
    assert_rgb_hsl(red, ['360', '100%', '50%'])
    assert_rgb_hsl(red, ['6120', '100%', '50%'])

    yellow = [255, 255, 0]
    assert_rgb_hsl(yellow, ['60', '100%', '50%'])
    assert_rgb_hsl(yellow, ['-300', '100%', '50%'])
    assert_rgb_hsl(yellow, ['420', '100%', '50%'])
    assert_rgb_hsl(yellow, ['-9660', '100%', '50%'])

    green = [0, 255, 0]
    assert_rgb_hsl(green, ['120', '100%', '50%'])
    assert_rgb_hsl(green, ['-240', '100%', '50%'])
    assert_rgb_hsl(green, ['480', '100%', '50%'])
    assert_rgb_hsl(green, ['99840', '100%', '50%'])

    cyan = [0, 255, 255]
    assert_rgb_hsl(cyan, ['180', '100%', '50%'])
    assert_rgb_hsl(cyan, ['-180', '100%', '50%'])
    assert_rgb_hsl(cyan, ['540', '100%', '50%'])
    assert_rgb_hsl(cyan, ['-900', '100%', '50%'])

    blue = [0, 0, 255]
    assert_rgb_hsl(blue, ['240', '100%', '50%'])
    assert_rgb_hsl(blue, ['-120', '100%', '50%'])
    assert_rgb_hsl(blue, ['600', '100%', '50%'])
    assert_rgb_hsl(blue, ['-104880', '100%', '50%'])

    purple = [255, 0, 255]
    assert_rgb_hsl(purple, ['300', '100%', '50%'])
    assert_rgb_hsl(purple, ['-60', '100%', '50%'])
    assert_rgb_hsl(purple, ['660', '100%', '50%'])
    assert_rgb_hsl(purple, ['2820', '100%', '50%'])
  end

  def test_hsl_checks_bounds
    assert_error_message("Saturation -114 must be between 0% and 100% for `hsl'", "hsl(10, -114, 12)");
    assert_error_message("Lightness 256 must be between 0% and 100% for `hsl'", "hsl(10, 10, 256%)");
  end

  def test_percentage
    assert_equal("50%",  evaluate("percentage(.5)"))
    assert_equal("100%", evaluate("percentage(1)"))
    assert_equal("25%",  evaluate("percentage(25px / 100px)"))
    assert_error_message("25px is not a unitless number for `percentage'", "percentage(25px)")
    assert_error_message("#cccccc is not a unitless number for `percentage'", "percentage(#ccc)")
    assert_error_message("string is not a unitless number for `percentage'", %Q{percentage("string")})
  end

  def test_numeric_transformations
    assert_equal("5",   evaluate("round(4.8)"))
    assert_equal("5px", evaluate("round(4.8px)"))
    assert_equal("5px", evaluate("round(5.49px)"))
    assert_equal("4",   evaluate("floor(4.8)"))
    assert_equal("4px", evaluate("floor(4.8px)"))
    assert_equal("5",   evaluate("ceil(4.1)"))
    assert_equal("5px", evaluate("ceil(4.8px)"))
    assert_equal("5",   evaluate("abs(-5)"))
    assert_equal("5px", evaluate("abs(-5px)"))
    assert_equal("5",   evaluate("abs(5)"))
    assert_equal("5px", evaluate("abs(5px)"))
    assert_error_message("#cccccc is not a number for `round'", "round(#ccc)")
    assert_error_message("foo is not a number for `floor'", "floor(\"foo\")")
    assert_error_message("a is not a number for `ceil'", "ceil(\"a\")")
    assert_error_message("#aaaaaa is not a number for `abs'", "abs(#aaa)")
  end

  private

  def assert_rgb_hsl(rgb, hsl)
    hsl = hsl.map {|v| Sass::Script::Parser.parse v, 0, 0 }
    assert_equal(rgb, Sass::Script::Functions.hsl(*hsl).value)
  end

  def evaluate(value)
    Sass::Script::Parser.parse(value, 0, 0).perform({}).to_s
  end

  def assert_error_message(message, value)
    evaluate(value)
    flunk("Error message expected but not raised: #{message}")
  rescue Sass::SyntaxError => e
    assert_equal(message, e.message)
  end

end
