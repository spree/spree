require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should have_sym(*args)" do
  it "should pass if #has_sym?(*args) returns true" do
    {:a => "A"}.should have_key(:a)
  end

  it "should fail if #has_sym?(*args) returns false" do
    lambda {
      {:b => "B"}.should have_key(:a)
    }.should fail_with("expected #has_key?(:a) to return true, got false")
  end

  it "should fail if target does not respond to #has_sym?" do
    lambda {
      Object.new.should have_key(:a)
    }.should raise_error(NoMethodError)
  end
  
  it "should reraise an exception thrown in #has_sym?(*args)" do
    o = Object.new
    def o.has_sym?(*args)
      raise "Funky exception"
    end
    lambda { o.should have_sym(:foo) }.should raise_error("Funky exception")
  end
end

describe "should_not have_sym(*args)" do
  it "should pass if #has_sym?(*args) returns false" do
    {:a => "A"}.should_not have_key(:b)
  end

  it "should fail if #has_sym?(*args) returns true" do
    lambda {
      {:a => "A"}.should_not have_key(:a)
    }.should fail_with("expected #has_key?(:a) to return false, got true")
  end

  it "should fail if target does not respond to #has_sym?" do
    lambda {
      Object.new.should have_key(:a)
    }.should raise_error(NoMethodError)
  end
  
  it "should reraise an exception thrown in #has_sym?(*args)" do
    o = Object.new
    def o.has_sym?(*args)
      raise "Funky exception"
    end
    lambda { o.should_not have_sym(:foo) }.should raise_error("Funky exception")
  end
end
