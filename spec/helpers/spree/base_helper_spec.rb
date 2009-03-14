require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe Spree::BaseHelper do

  before(:each) do 
    @variant = mock_model(Variant, :option_values => [], :null_object => true)
    @variant.should_receive(:in_stock).and_return(false)
  end
  describe "variant_options" do
    describe "with :allow_backorders => true" do
      before(:each) { Spree::Config.stub!(:[]).with(:allow_backorders).and_return(true) }
      it "should not mention 'out of stock'" do
        helper.variant_options(@variant).should_not include("Out of Stock")
      end
      it "should mention 'out of stock' when passing allow_back_orders = false" do
        helper.variant_options(@variant, false).should include("Out of Stock")
      end
    end

    describe "with :allow_backorders => false" do
      before(:each) { Spree::Config.stub!(:[]).with(:allow_backorders).and_return(false) }    
      it "should mention 'out of stock'" do
        helper.variant_options(@variant).should include("Out of Stock")        
      end
      it "should not mention 'out of stock' when passing allow_back_orders = true" do
        helper.variant_options(@variant, true).should_not include("Out of Stock")
      end
    end
  end
end
