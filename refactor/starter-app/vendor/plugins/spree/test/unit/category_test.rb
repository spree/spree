require File.dirname(__FILE__) + '/../test_helper'

class CategoryTest < Test::Unit::TestCase

  TT = ["taxable"]
  VARIATIONS = ["mock variation"]
  
  def setup
    @c = Category.new
    @tt = TaxTreatment.new
  end

  def test_tax_treatments_parent
    pc = Category.new
    pc.stubs(:tax_treatments).returns TT
    @c.parent = pc
    assert_equal TT, @c.tax_treatments
    assert @c.tax_treatments.frozen?, "tax treatments should be frozen"
  end

  def test_tax_treatments_no_parent
    @c.tax_treatments << @tt
    assert_equal [@tt], @c.tax_treatments
    assert (not @c.tax_treatments.frozen?), "tax treatments should not be frozen"
  end

  def test_no_tax_treatments_no_parent
    assert_equal [], @c.tax_treatments
    assert (not @c.tax_treatments.frozen?), "tax treatments should not be frozen"
  end

  def test_variations_parent
    pc = Category.new
    pc.stubs(:variations).returns VARIATIONS
    @c.parent = pc
    assert (@c.variations == VARIATIONS)
    assert (@c.variations.frozen?)
  end

  def test_variations_no_parent
    @c.stubs(:variations).returns VARIATIONS
    assert (@c.variations == VARIATIONS)
    assert (not @c.variations.frozen?)
  end

  def test_no_variations_no_parent
    v = []
    @c.stubs(:variations).returns v
    assert (@c.variations == v)
    assert (not @c.variations.frozen?)
  end
end