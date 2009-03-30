require  File.dirname(__FILE__)+'/test_helper'
require 'compass'

class SassExtensionsTest < Test::Unit::TestCase
  def test_simple
    assert_equal "a b", nest("a", "b")
  end
  def test_left_side_expansion
    assert_equal "a c, b c", nest("a, b", "c")
  end
  def test_right_side_expansion
    assert_equal "a b, a c", nest("a", "b, c")
  end
  def test_both_sides_expansion
    assert_equal "a c, a d, b c, b d", nest("a, b", "c, d")
  end
  def test_three_selectors_expansion
    assert_equal "a b, a c, a d", nest("a", "b, c, d")
  end
  def test_third_argument_expansion
    assert_equal "a b e, a b f, a c e, a c f, a d e, a d f", nest("a", "b, c, d", "e, f")
  end
  def nest(*arguments)
    Sass::Script::Functions.nest(*arguments.map{|a| Sass::Script::String.new(a)}).to_s
  end
end