require File.dirname(__FILE__) + '/../../spec_helper'

describe "IvarProxy setup", :shared => true do
  before do
    @object = Object.new
    @proxy = Spec::Rails::Example::IvarProxy.new(@object)
  end  
end

describe "IvarProxy" do
  it_should_behave_like "IvarProxy setup"
  
  it "has [] accessor" do
    @proxy['foo'] = 'bar'
    @object.instance_variable_get(:@foo).should == 'bar'
    @proxy['foo'].should == 'bar'
  end

  it "iterates through each element like a Hash" do
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

  it "detects the presence of a key" do
    @proxy['foo'] = 'bar'
    @proxy.has_key?('foo').should == true
    @proxy.has_key?('bar').should == false
  end
end

describe "IvarProxy", "#delete" do
  it_should_behave_like "IvarProxy setup"
  
  it "deletes the element with key" do
    @proxy['foo'] = 'bar'
    @proxy.delete('foo').should == 'bar'
    @proxy['foo'].should be_nil
  end

  it "deletes nil instance variables" do
    @proxy['foo'] = nil
    @object.instance_variables.should include("@foo")
    @proxy.delete('foo').should == nil
    @proxy['foo'].should be_nil
    @object.instance_variables.should_not include("@foo")
  end

  it "returns nil when key does not exist" do
    @proxy['foo'].should be_nil
    @proxy.delete('foo').should == nil
    @proxy['foo'].should be_nil
  end
end
