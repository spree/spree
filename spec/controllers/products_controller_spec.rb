require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ProductsController do
  describe "Normal products route recognition" do
 
    it "should generate params { :controller => 'products', action => 'index' } from GET /products" do
      params_from(:get, "/products").should == {:controller => "products", :action => "index"}
    end
    
    it "should generate params { :controller => 'products', action => 'show', id => '1' } from GET /products" do
      params_from(:get, "/products/1").should == {:controller => "products", :action => "show", :id => "1"}
    end

  end

end
