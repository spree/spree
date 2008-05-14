require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::TaxRatesController do

  fixtures :users, :roles
  integrate_views
  
  before { login(:admin) }
  
  it "should allow the index to render even with there are no tax rates" do
    TaxRate.destroy_all
    get :index
    response.should be_success
    assigns(:tax_rates).should_not be_nil
  end
  
  it "should display all of the tax rates in the database on index action" do
    get :index
    
  end
  
end