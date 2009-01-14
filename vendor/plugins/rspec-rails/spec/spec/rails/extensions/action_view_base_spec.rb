require File.dirname(__FILE__) + '/../../../spec_helper'
require 'spec/mocks/errors'

describe ActionView::Base, "with RSpec extensions:", :type => :view do 
  
  describe "should_receive(:render)" do
    it "should not raise when render has been received" do
      template.should_receive(:render).with(:partial => "name")
      template.render :partial => "name"
    end
  
    it "should raise when render has NOT been received" do
      template.should_receive(:render).with(:partial => "name")
      lambda {
        template.verify_rendered
      }.should raise_error
    end
    
    it "should return something (like a normal mock)" do
      template.should_receive(:render).with(:partial => "name").and_return("Little Johnny")
      result = template.render :partial => "name"
      result.should == "Little Johnny"
    end
  end
  
  describe "stub!(:render)" do
    it "should not raise when stubbing and render has been received" do
      template.stub!(:render).with(:partial => "name")
      template.render :partial => "name"
    end
  
    it "should not raise when stubbing and render has NOT been received" do
      template.stub!(:render).with(:partial => "name")
    end
  
    it "should not raise when stubbing and render has been received with different options" do
      template.stub!(:render).with(:partial => "name")
      template.render :partial => "view_spec/spacer"
    end

    it "should not raise when stubbing and expecting and render has been received" do
      template.stub!(:render).with(:partial => "name")
      template.should_receive(:render).with(:partial => "name")
      template.render(:partial => "name")
    end
  end

end
