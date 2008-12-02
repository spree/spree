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
  
  describe "Nested taxons with products route recognition" do
    it "should generate params { :controller => 'products', action => 'show', id => 'ruby-on-rails-jr-spaghetti', taxon_path=>['categories', 'clothing', 'shirts']} from GET /t/categories/clothing/shirts/p/ruby-on-rails-jr-spaghetti" do
      params_from(:get, "/t/categories/clothing/shirts/p/ruby-on-rails-jr-spaghetti").should == {:controller => "products", :action => "show", :id => 'ruby-on-rails-jr-spaghetti', :taxon_path => ['categories', 'clothing', 'shirts']}
    end
    
    it "should generate params { :controller => 'products', action => 'show', id => 'apache-baseball-jersey', taxon_path=>['categories', 'clothing', 'shirts']} from GET /t/categories/clothing/shirts/t-shirts/p/apache-baseball-jersey" do
      params_from(:get, "/t/categories/clothing/shirts/t-shirts/p/apache-baseball-jersey").should == {:controller => "products", :action => "show", :id => 'apache-baseball-jersey', :taxon_path => ['categories', 'clothing', 'shirts', 't-shirts']}
    end
 
  end
end
