require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationController do
  
  before(:each) do 
  end
    
  it "should map :controller => 'admin/tax_rates', :action => 'index') to /admin/tax_rates" do
    route_for(:controller => 'admin/tax_rates', :action => 'index').should == "/admin/tax_rates"
  end

end