require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../spec_helper'

describe <%= controller_class_name %>Controller do
  describe "route generation" do

    it "should map { :controller => '<%= table_name %>', :action => 'index' } to /<%= table_name %>" do
      route_for(:controller => "<%= table_name %>", :action => "index").should == "/<%= table_name %>"
    end
  
    it "should map { :controller => '<%= table_name %>', :action => 'new' } to /<%= table_name %>/new" do
      route_for(:controller => "<%= table_name %>", :action => "new").should == "/<%= table_name %>/new"
    end
  
    it "should map { :controller => '<%= table_name %>', :action => 'show', :id => 1 } to /<%= table_name %>/1" do
      route_for(:controller => "<%= table_name %>", :action => "show", :id => 1).should == "/<%= table_name %>/1"
    end
  
    it "should map { :controller => '<%= table_name %>', :action => 'edit', :id => 1 } to /<%= table_name %>/1<%= resource_edit_path %>" do
      route_for(:controller => "<%= table_name %>", :action => "edit", :id => 1).should == "/<%= table_name %>/1<%= resource_edit_path %>"
    end
  
    it "should map { :controller => '<%= table_name %>', :action => 'update', :id => 1} to /<%= table_name %>/1" do
      route_for(:controller => "<%= table_name %>", :action => "update", :id => 1).should == "/<%= table_name %>/1"
    end
  
    it "should map { :controller => '<%= table_name %>', :action => 'destroy', :id => 1} to /<%= table_name %>/1" do
      route_for(:controller => "<%= table_name %>", :action => "destroy", :id => 1).should == "/<%= table_name %>/1"
    end
  end

  describe "route recognition" do

    it "should generate params { :controller => '<%= table_name %>', action => 'index' } from GET /<%= table_name %>" do
      params_from(:get, "/<%= table_name %>").should == {:controller => "<%= table_name %>", :action => "index"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'new' } from GET /<%= table_name %>/new" do
      params_from(:get, "/<%= table_name %>/new").should == {:controller => "<%= table_name %>", :action => "new"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'create' } from POST /<%= table_name %>" do
      params_from(:post, "/<%= table_name %>").should == {:controller => "<%= table_name %>", :action => "create"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'show', id => '1' } from GET /<%= table_name %>/1" do
      params_from(:get, "/<%= table_name %>/1").should == {:controller => "<%= table_name %>", :action => "show", :id => "1"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'edit', id => '1' } from GET /<%= table_name %>/1;edit" do
      params_from(:get, "/<%= table_name %>/1<%= resource_edit_path %>").should == {:controller => "<%= table_name %>", :action => "edit", :id => "1"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'update', id => '1' } from PUT /<%= table_name %>/1" do
      params_from(:put, "/<%= table_name %>/1").should == {:controller => "<%= table_name %>", :action => "update", :id => "1"}
    end
  
    it "should generate params { :controller => '<%= table_name %>', action => 'destroy', id => '1' } from DELETE /<%= table_name %>/1" do
      params_from(:delete, "/<%= table_name %>/1").should == {:controller => "<%= table_name %>", :action => "destroy", :id => "1"}
    end
  end
end