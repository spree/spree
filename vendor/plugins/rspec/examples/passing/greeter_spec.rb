require File.dirname(__FILE__) + '/spec_helper'
# greeter.rb
#
# Based on http://glu.ttono.us/articles/2006/12/19/tormenting-your-tests-with-heckle
#
# Run with:
#
#   spec greeter_spec.rb --heckle Greeter
#
class Greeter
  def initialize(person = nil)
    @person = person
  end

  def greet
    @person.nil? ? "Hi there!" : "Hi #{@person}!"
  end
end

describe "Greeter" do
  it "should say Hi to person" do
    greeter = Greeter.new("Kevin")
    greeter.greet.should == "Hi Kevin!"
  end

  it "should say Hi to nobody" do
    greeter = Greeter.new
    # Uncomment the next line to make Heckle happy
    #greeter.greet.should == "Hi there!"
  end
end
