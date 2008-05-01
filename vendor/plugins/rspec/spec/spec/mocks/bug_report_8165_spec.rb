require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "An object where respond_to? is true and does not have method" do
  # When should_receive(:sym) is sent to any object, the Proxy sends
  # respond_to?(:sym) to that object to see if the method should be proxied.
  #
  # If respond_to? itself is proxied, then when the Proxy sends respond_to?
  # to the object, the proxy is invoked and responds yes (if so set in the spec).
  # When the object does NOT actually respond to :sym, an exception is thrown
  # when trying to proxy it.
  #
  # The fix was to keep track of whether :respond_to? had been proxied and, if
  # so, call the munged copy of :respond_to? on the object.

  it "should not raise an exception for Object" do
    obj = Object.new
    obj.should_receive(:respond_to?).with(:foobar).and_return(true)
    obj.should_receive(:foobar).and_return(:baz)
    obj.respond_to?(:foobar).should be_true
    obj.foobar.should == :baz
  end

  it "should not raise an exception for mock" do
    obj = mock("obj")
    obj.should_receive(:respond_to?).with(:foobar).and_return(true)
    obj.should_receive(:foobar).and_return(:baz)
    obj.respond_to?(:foobar).should be_true
    obj.foobar.should == :baz
  end

end
