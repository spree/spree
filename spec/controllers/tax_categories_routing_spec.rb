require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Admin::TaxCategoriesController do
  describe "route generation" do

    it "should map { :controller => 'admin/tax_categories', :action => 'index' } to /admin/tax_categories" do
      route_for(:controller => "admin/tax_categories", :action => "index").should == "/admin/tax_categories"
    end
  
    it "should map { :controller => 'admin/tax_categories', :action => 'new' } to /admin/tax_categories/new" do
      route_for(:controller => "admin/tax_categories", :action => "new").should == "/admin/tax_categories/new"
    end
  
    it "should map { :controller => 'admin/tax_categories', :action => 'show', :id => 1 } to /admin/tax_categories/1" do
      route_for(:controller => "admin/tax_categories", :action => "show", :id => 1).should == "/admin/tax_categories/1"
    end
  
    it "should map { :controller => 'admin/tax_categories', :action => 'edit', :id => 1 } to /admin/tax_categories/1/edit" do
      route_for(:controller => "admin/tax_categories", :action => "edit", :id => 1).should == "/admin/tax_categories/1/edit"
    end
  
    it "should map { :controller => 'admin/tax_categories', :action => 'update', :id => 1} to /admin/tax_categories/1" do
      route_for(:controller => "admin/tax_categories", :action => "update", :id => 1).should == "/admin/tax_categories/1"
    end
  
    it "should map { :controller => 'admin/tax_categories', :action => 'destroy', :id => 1} to /admin/tax_categories/1" do
      route_for(:controller => "admin/tax_categories", :action => "destroy", :id => 1).should == "/admin/tax_categories/1"
    end
  end

  describe "route recognition" do

    it "should generate params { :controller => 'admin/tax_categories', action => 'index' } from GET /admin/tax_categories" do
      params_from(:get, "/admin/tax_categories").should == {:controller => "admin/tax_categories", :action => "index"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'new' } from GET /admin/tax_categories/new" do
      params_from(:get, "/admin/tax_categories/new").should == {:controller => "admin/tax_categories", :action => "new"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'create' } from POST /admin/tax_categories" do
      params_from(:post, "/admin/tax_categories").should == {:controller => "admin/tax_categories", :action => "create"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'show', id => '1' } from GET /admin/tax_categories/1" do
      params_from(:get, "/admin/tax_categories/1").should == {:controller => "admin/tax_categories", :action => "show", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'edit', id => '1' } from GET /admin/tax_categories/1;edit" do
      params_from(:get, "/admin/tax_categories/1/edit").should == {:controller => "admin/tax_categories", :action => "edit", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'update', id => '1' } from PUT /admin/tax_categories/1" do
      params_from(:put, "/admin/tax_categories/1").should == {:controller => "admin/tax_categories", :action => "update", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/tax_categories', action => 'destroy', id => '1' } from DELETE /admin/tax_categories/1" do
      params_from(:delete, "/admin/tax_categories/1").should == {:controller => "admin/tax_categories", :action => "destroy", :id => "1"}
    end
  end
end
