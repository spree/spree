require File.dirname(__FILE__) + '/../spec_helper'

describe CheckoutController do
  
  before(:each) do 
    @new_york = mock_model State, :name => "New York"
    @ship_address = mock_model Address, {:state => @new_york}
    @order = mock_model Order, {:item_total => 100, :ship_address => @ship_address}
    @tax_rate = mock_model TaxRate, {:state => @new_york, :rate => 0.075} 
  end
  
  it "should include a calculate_tax method" do
    controller.respond_to?(:calculate_tax).should be_true
  end
  
  it "should map :controller => 'admin/tax_rates', :action => 'index') to /admin/tax_rates" do
    route_for(:controller => 'admin/tax_rates', :action => 'index').should == "/admin/tax_rates"
  end
  
  it "should not apply tax if there are no tax rates present" do
    TaxRate.stub!(:find).and_return(nil)
    @order.should_receive(:tax_amount=).with(0)
    controller.calculate_tax(@order)
  end
  
  it "should only apply tax to orders that are shipping to a state with a tax rate" do
    TaxRate.stub!(:find).and_return(@tax_rate)
    california = mock_model State, :name => "California"
    @ship_address = mock_model Address, :state => california
    @order.should_receive(:tax_amount=).with(7.5)
    controller.calculate_tax(@order)
  end
end