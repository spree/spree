require File.dirname(__FILE__) + '/../spec_helper'

describe CheckoutController do
  
  before(:each) do 
    @new_york = mock_model State, :name => "New York"
    @ship_address = mock_model Address, {:state => @new_york}
    @order = mock_model Order, {:item_total => 100, :ship_address => @ship_address}
    @tax_rate = mock_model TaxRate, {:state => @new_york, :rate => 0.075} 
  end
    
  it "should map :controller => 'admin/tax_rates', :action => 'index') to /admin/tax_rates" do
    route_for(:controller => 'admin/tax_rates', :action => 'index').should == "/admin/tax_rates"
  end

end