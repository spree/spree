require File.dirname(__FILE__) + '/../test_helper'
require 'tax/sales_tax'

class SalesTaxTest < Test::Unit::TestCase
  LI_TOTAL = 100
    
  def setup
    state = stub(:abbr => "NY")
    ship_address = stub(:state => state)
    line_items = []
    line_items << non_taxable_li
    line_items << taxable_li
    @order = Object.new
    @order.stubs(:line_items).returns(line_items)
    @order.stubs(:ship_address).returns(ship_address)
  end

  def non_taxable_li
    prod = Object.new
    prod.stubs(:apply_tax_treatment?).returns false
    li_nt = Object.new
    li_nt.stubs(:total).returns LI_TOTAL 
    li_nt.stubs(:product).returns prod
    li_nt
  end

  def taxable_li
    prod = Object.new
    prod.stubs(:apply_tax_treatment?).returns true
    li_t = Object.new
    li_t.stubs(:total).returns LI_TOTAL
    li_t.stubs(:product).returns prod
    li_t
  end
    
  def test_tax_free_state
    SalesTax.rate_map = {:NJ => 0.05}
    assert_equal 0, SalesTax.calc_tax(@order)    
  end
  
  def test_taxable_state
    SalesTax.rate_map = {:NY => 0.05}
    assert_equal 5, SalesTax.calc_tax(@order)    
  end

end