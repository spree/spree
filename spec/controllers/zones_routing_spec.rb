require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Admin::ZonesController do
  describe "route generation" do

    it "should map { :controller => 'admin/zones', :action => 'index' } to /admin/zones" do
      route_for(:controller => "admin/zones", :action => "index").should == "/admin/zones"
    end
  
    it "should map { :controller => 'admin/zones', :action => 'new' } to /admin/zones/new" do
      route_for(:controller => "admin/zones", :action => "new").should == "/admin/zones/new"
    end
  
    it "should map { :controller => 'admin/zones', :action => 'show', :id => 1 } to /admin/zones/1" do
      route_for(:controller => "admin/zones", :action => "show", :id => 1).should == "/admin/zones/1"
    end
  
    it "should map { :controller => 'admin/zones', :action => 'edit', :id => 1 } to /admin/zones/1/edit" do
      route_for(:controller => "admin/zones", :action => "edit", :id => 1).should == "/admin/zones/1/edit"
    end
  
    it "should map { :controller => 'admin/zones', :action => 'update', :id => 1} to /admin/zones/1" do
      route_for(:controller => "admin/zones", :action => "update", :id => 1).should == "/admin/zones/1"
    end
  
    it "should map { :controller => 'admin/zones', :action => 'destroy', :id => 1} to /admin/zones/1" do
      route_for(:controller => "admin/zones", :action => "destroy", :id => 1).should == "/admin/zones/1"
    end
  end

  describe "route recognition" do

    it "should generate params { :controller => 'admin/zones', action => 'index' } from GET /admin/zones" do
      params_from(:get, "/admin/zones").should == {:controller => "admin/zones", :action => "index"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'new' } from GET /admin/zones/new" do
      params_from(:get, "/admin/zones/new").should == {:controller => "admin/zones", :action => "new"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'create' } from POST /admin/zones" do
      params_from(:post, "/admin/zones").should == {:controller => "admin/zones", :action => "create"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'show', id => '1' } from GET /admin/zones/1" do
      params_from(:get, "/admin/zones/1").should == {:controller => "admin/zones", :action => "show", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'edit', id => '1' } from GET /admin/zones/1;edit" do
      params_from(:get, "/admin/zones/1/edit").should == {:controller => "admin/zones", :action => "edit", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'update', id => '1' } from PUT /admin/zones/1" do
      params_from(:put, "/admin/zones/1").should == {:controller => "admin/zones", :action => "update", :id => "1"}
    end
  
    it "should generate params { :controller => 'admin/zones', action => 'destroy', id => '1' } from DELETE /admin/zones/1" do
      params_from(:delete, "/admin/zones/1").should == {:controller => "admin/zones", :action => "destroy", :id => "1"}
    end
  end
end
