require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe TaxonsController do
  describe "Nested taxons route recognition" do
    it "should generate params { :controller => 'taxons', action => 'show', id => ['categories'], } from GET /t/categories/" do
      params_from(:get, "/t/categories/").should == {:controller => "taxons", :action => "show", :id => ['categories']}
    end

    it "should generate params { :controller => 'taxons', action => 'show', id => ['categories', 'clothing'], } from GET /t/categories/clothing/" do
      params_from(:get, "/t/categories/clothing/").should == {:controller => "taxons", :action => "show", :id => ['categories', 'clothing']}
    end
    
    it "should generate params { :controller => 'taxons', action => 'show', id => ['categories', 'clothing', 'shirts'], } from GET /t/categories/clothing/shirts" do
      params_from(:get, "/t/categories/clothing/shirts/").should == {:controller => "taxons", :action => "show", :id => ['categories', 'clothing', 'shirts']}
    end
 
  end
end
