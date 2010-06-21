require 'test_helper'

class Spree::BaseHelperTest < ActionView::TestCase
  context "when backordering is allowed" do
    setup do 
      Spree::Config.set(:allow_backorders => true)
    end
    context "and variant is out of stock" do
      setup { @variant = Factory(:variant, :on_hand => "0")}
      context "variant_options" do
        setup { @variant_options = variant_options(@variant) }
        should "not mention out of stock" do
          assert !@variant_options.include?("Out of Stock")
        end
      end
      context "variant_options(allow_backordering=false)" do
        setup { @variant_options = variant_options(@variant, false) }
        should "not mention out of stock" do
          assert @variant_options.include?("Out of Stock")
        end
      end
    end
  end
  context "when backordering is disallowed" do
    setup { Spree::Config.set(:allow_backorders => false) }
    teardown { Spree::Config.set(:allow_backorders => true) }
    context "and variant is out of stock" do
      setup { @variant = Factory(:variant, :on_hand => "0")}
      context "variant_options" do
        setup { @variant_options = variant_options(@variant) }
        should "not mention out of stock" do
          assert @variant_options.include?("Out of Stock")
        end
      end
      context "variant_options(allow_backordering=true)" do
        setup { @variant_options = variant_options(@variant, true) }
        should "not mention out of stock" do
          assert !@variant_options.include?("Out of Stock")
        end
      end
    end
  end  
end