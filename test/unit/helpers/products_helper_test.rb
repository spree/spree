require 'test_helper'

class ProductsHelperTest < ActionView::TestCase
  context "format_price" do
    setup { @price = 100 }
    should "format the price using $ when locale is en-US" do
      assert format_price(@price).include?("$100.00")
    end
    should "should include the '(inc. VAT)' text when options[:show_vat_text] => true" do
      assert_equal "$100.00 (inc. VAT)", format_price(@price, :show_vat_text => true)
    end
    should "not include the '(inc. VAT)' text when options[:show_vat_text] => false" do
      assert_equal "$100.00", format_price(@price, :show_vat_text => false)
    end
    context "with options[:show_vat_text] => nil" do
      should "include the '(inc. VAT)' text when Spree::Config[:show_price_inc_vat] => true" do
        Spree::Config.set(:show_price_inc_vat => true)
        assert_equal "$100.00 (inc. VAT)", format_price(@price)
      end
      should "not include the '(inc. VAT)' text when Spree::onfig[:show_price_inc_vat] => false" do
        Spree::Config.set(:show_price_inc_vat => false)
        assert_equal "$100.00", format_price(@price)
      end
    end    
  end  
=begin
  should "format the price using $ when locale is es" do
    I18n.locale = "es"
    assert_equal "100,00 €", format_price(@price)
  end 
=end
end