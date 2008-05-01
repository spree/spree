require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should respond_to(:sym)" do
  
  it "should pass if target responds to :sym" do
    Object.new.should respond_to(:methods)
  end
  
  it "should fail target does not respond to :sym" do
    lambda {
      Object.new.should respond_to(:some_method)
    }.should fail_with("expected target to respond to :some_method")
  end
  
end

describe "should respond_to(message1, message2)" do
  
  it "should pass if target responds to both messages" do
    Object.new.should respond_to('methods', 'inspect')
  end
  
  it "should fail target does not respond to first message" do
    lambda {
      Object.new.should respond_to('method_one', 'inspect')
    }.should fail_with('expected target to respond to "method_one"')
  end
  
  it "should fail target does not respond to second message" do
    lambda {
      Object.new.should respond_to('inspect', 'method_one')
    }.should fail_with('expected target to respond to "method_one"')
  end
  
  it "should fail target does not respond to either message" do
    lambda {
      Object.new.should respond_to('method_one', 'method_two')
    }.should fail_with('expected target to respond to "method_one", "method_two"')
  end
end

describe "should_not respond_to(:sym)" do
  
  it "should pass if target does not respond to :sym" do
    Object.new.should_not respond_to(:some_method)
  end
  
  it "should fail target responds to :sym" do
    lambda {
      Object.new.should_not respond_to(:methods)
    }.should fail_with("expected target not to respond to :methods")
  end
  
end
