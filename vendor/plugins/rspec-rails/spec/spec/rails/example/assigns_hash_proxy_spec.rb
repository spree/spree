require File.dirname(__FILE__) + '/../../../spec_helper'

describe "AssignsHashProxy" do
  def orig_assigns
    @object.assigns
  end
  
  before(:each) do
    @object = Class.new do
      attr_accessor :assigns
    end.new
    @object.assigns = Hash.new
    @proxy = Spec::Rails::Example::AssignsHashProxy.new self do
      @object
    end
  end
  
  it "should set ivars on object using string" do
    @proxy['foo'] = 'bar'
    @object.instance_eval{@foo}.should == 'bar'
  end
  
  it "should set ivars on object using symbol" do
    @proxy[:foo] = 'bar'
    @object.instance_eval{@foo}.should == 'bar'
  end
  
  it "should access object's assigns with a string" do
    @object.assigns['foo'] = 'bar'
    @proxy['foo'].should == 'bar'
  end
  
  it "should access object's assigns with a symbol" do
    @object.assigns['foo'] = 'bar'
    @proxy[:foo].should == 'bar'
  end

  it "should access object's ivars with a string" do
    @object.instance_variable_set('@foo', 'bar')
    @proxy['foo'].should == 'bar'
  end
  
  it "should access object's ivars with a symbol" do
    @object.instance_variable_set('@foo', 'bar')
    @proxy[:foo].should == 'bar'
  end

  it "should iterate through each element like a Hash" do
    values = {
      'foo' => 1,
      'bar' => 2,
      'baz' => 3
    }
    @proxy['foo'] = values['foo']
    @proxy['bar'] = values['bar']
    @proxy['baz'] = values['baz']
  
    @proxy.each do |key, value|
      key.should == key
      value.should == values[key]
    end
  end
  
  it "should delete the ivar of passed in key" do
    @object.instance_variable_set('@foo', 'bar')
    @proxy.delete('foo')
    @proxy['foo'].should be_nil
  end
  
  it "should delete the assigned element of passed in key" do
    @object.assigns['foo'] = 'bar'
    @proxy.delete('foo')
    @proxy['foo'].should be_nil
  end
  
  it "should detect the presence of a key in assigns" do
    @object.assigns['foo'] = 'bar'
    @proxy.has_key?('foo').should == true
    @proxy.has_key?('bar').should == false
  end
  
  it "should expose values set in example back to the example" do
    @proxy[:foo] = 'bar'
    @proxy[:foo].should == 'bar'
  end
  
  it "should allow assignment of false via proxy" do
    @proxy['foo'] = false
    @proxy['foo'].should be_false
  end
  
  it "should allow assignment of false" do
    @object.instance_variable_set('@foo',false)
    @proxy['foo'].should be_false
  end
end
