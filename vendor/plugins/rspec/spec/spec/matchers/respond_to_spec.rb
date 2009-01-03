require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should respond_to(:sym)" do
  
  it "passes if target responds to :sym" do
    Object.new.should respond_to(:methods)
  end
  
  it "fails if target does not respond to :sym" do
    lambda {
      "this string".should respond_to(:some_method)
    }.should fail_with(%q|expected "this string" to respond to :some_method|)
  end
  
end

describe "should respond_to(:sym).with(1).argument" do
  it "passes if target responds to :sym with 1 arg" do
    obj = Object.new
    def obj.foo(arg); end
    obj.should respond_to(:foo).with(1).argument
  end
  
  it "fails if target does not respond to :sym" do
    obj = Object.new
    lambda {
      obj.should respond_to(:some_method).with(1).argument
    }.should fail_with(/expected .* to respond to :some_method/)
  end
  
  it "fails if :sym expects 0 args" do
    obj = Object.new
    def obj.foo; end
    lambda {
      obj.should respond_to(:foo).with(1).argument
    }.should fail_with(/expected #<Object.*> to respond to :foo with 1 argument/)
  end
  
  it "fails if :sym expects 2 args" do
    obj = Object.new
    def obj.foo(arg, arg2); end
    lambda {
      obj.should respond_to(:foo).with(1).argument
    }.should fail_with(/expected #<Object.*> to respond to :foo with 1 argument/)
  end
end

describe "should respond_to(message1, message2)" do
  
  it "passes if target responds to both messages" do
    Object.new.should respond_to('methods', 'inspect')
  end
  
  it "fails if target does not respond to first message" do
    lambda {
      Object.new.should respond_to('method_one', 'inspect')
    }.should fail_with(/expected #<Object:.*> to respond to "method_one"/)
  end
  
  it "fails if target does not respond to second message" do
    lambda {
      Object.new.should respond_to('inspect', 'method_one')
    }.should fail_with(/expected #<Object:.*> to respond to "method_one"/)
  end
  
  it "fails if target does not respond to either message" do
    lambda {
      Object.new.should respond_to('method_one', 'method_two')
    }.should fail_with(/expected #<Object:.*> to respond to "method_one", "method_two"/)
  end
end

describe "should respond_to(:sym).with(2).arguments" do
  it "passes if target responds to :sym with 2 args" do
    obj = Object.new
    def obj.foo(a1, a2); end
    obj.should respond_to(:foo).with(2).arguments
  end
  
  it "fails if target does not respond to :sym" do
    obj = Object.new
    lambda {
      obj.should respond_to(:some_method).with(2).arguments
    }.should fail_with(/expected .* to respond to :some_method/)
  end
  
  it "fails if :sym expects 0 args" do
    obj = Object.new
    def obj.foo; end
    lambda {
      obj.should respond_to(:foo).with(2).arguments
    }.should fail_with(/expected #<Object.*> to respond to :foo with 2 arguments/)
  end
  
  it "fails if :sym expects 2 args" do
    obj = Object.new
    def obj.foo(arg); end
    lambda {
      obj.should respond_to(:foo).with(2).arguments
    }.should fail_with(/expected #<Object.*> to respond to :foo with 2 arguments/)
  end
end

describe "should_not respond_to(:sym)" do
  
  it "passes if target does not respond to :sym" do
    Object.new.should_not respond_to(:some_method)
  end
  
  it "fails if target responds to :sym" do
    lambda {
      Object.new.should_not respond_to(:methods)
    }.should fail_with(/expected #<Object:.*> not to respond to :methods/)
  end
  
end
