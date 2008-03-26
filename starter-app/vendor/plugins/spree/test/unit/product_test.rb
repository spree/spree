require File.dirname(__FILE__) + '/../test_helper'

class ProductTest < Test::Unit::TestCase
  
  TT = ["mock tax treatment"]
  
  def setup
    @tt = stub(:id => 1, :name => "taxable")
    #@v = stub(:id => 1, :name => "mock variation")
    @c = Category.new
    @p = Product.new
  end

  def test_apply_tax_treatment_category_has_treatment
    c = Object.new
    c.stubs(:tax_treatments).returns [@tt]
    p = Product.new
    p.stubs(:category).returns c
    assert (p.apply_tax_treatment? @tt.id)
  end

  def test_apply_tax_treatment_category_has_no_treatment
    c = Object.new
    c.stubs(:tax_treatments).returns []
    p = Product.new
    p.stubs(:category).returns c
    assert !(p.apply_tax_treatment? @tt.id)
  end

  def test_apply_tax_treatment_product_has_treatment
    p = Product.new
    p.stubs(:category).returns nil
    p.stubs(:tax_treatments).returns [@tt]
    assert (p.apply_tax_treatment? @tt.id)
  end

  def test_apply_tax_treatment_product_has_no_treatment
    p = Product.new
    p.stubs(:category).returns nil
    p.stubs(:tax_treatments).returns []
    assert !(p.apply_tax_treatment? @tt.id)
  end

  def test_tax_no_category
    assert @p.tax_treatments.empty?
    assert (not @p.tax_treatments.frozen?)
  end
  
  def test_tax_empty_category
    @p.category = @c
    assert @p.tax_treatments.empty?
    assert (not @p.tax_treatments.frozen?)
    tt = TaxTreatment.new
    @p.tax_treatments << tt
    assert (@p.tax_treatments == [tt])
    assert !(@p.tax_treatments.frozen?)
  end
  
  def test_tax_category
    @c.stubs(:tax_treatments).returns TT
    @p.category = @c
    assert_equal TT, @p.tax_treatments
    assert @p.tax_treatments.frozen?, "tax treatments should be frozen"
  end
  
  def test_tax_parent_category
    pc = Category.new
    pc.stubs(:tax_treatments).returns TT
    @c.parent = pc
    @p.category = @c
    assert (@p.tax_treatments == TT)
    assert @p.tax_treatments.frozen?, "tax treatments should be frozen"
  end  
end 