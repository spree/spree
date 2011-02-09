require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingMethod do
  context 'factory' do
    let(:shipping_method){ Factory :shipping_method }

    it "should set calculable correctly" do
      shipping_method.calculator.calculable.should == shipping_method
    end
  end

  context 'validations' do
    it { should have_valid_factory(:shipping_method) }
  end

end
