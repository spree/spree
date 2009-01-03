#Based on patch from Wilson Bilkovich

require File.dirname(__FILE__) + '/../../spec_helper.rb'
class SomethingExpected
  attr_accessor :some_value
end

describe "should change(actual, message)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when actual is modified by the block" do
    lambda {@instance.some_value = 6}.should change(@instance, :some_value)
  end

  it "should fail when actual is not modified by the block" do
    lambda do
      lambda {}.should change(@instance, :some_value)
    end.should fail_with("some_value should have changed, but is still 5")
  end
end

describe "should_not change(actual, message)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when actual is not modified by the block" do
    lambda { }.should_not change(@instance, :some_value)
  end

  it "should fail when actual is not modified by the block" do
    lambda do
      lambda {@instance.some_value = 6}.should_not change(@instance, :some_value)
    end.should fail_with("some_value should not have changed, but did change from 5 to 6")
  end
end

describe "should change { block }" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when actual is modified by the block" do
    lambda {@instance.some_value = 6}.should change { @instance.some_value }
  end

  it "should fail when actual is not modified by the block" do
    lambda do
      lambda {}.should change{ @instance.some_value }
    end.should fail_with("result should have changed, but is still 5")
  end
  
  it "should warn if passed a block using do/end instead of {}" do
    lambda do
      lambda {}.should change do; end
    end.should raise_error(Spec::Matchers::MatcherError, /block passed to should or should_not/)
  end
end

describe "should_not change { block }" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when actual is modified by the block" do
    lambda {}.should_not change{ @instance.some_value }
  end

  it "should fail when actual is not modified by the block" do
    lambda do
      lambda {@instance.some_value = 6}.should_not change { @instance.some_value }
    end.should fail_with("result should not have changed, but did change from 5 to 6")
  end
  
  it "should warn if passed a block using do/end instead of {}" do
    lambda do
      lambda {}.should_not change do; end
    end.should raise_error(Spec::Matchers::MatcherError, /block passed to should or should_not/)
  end
end

describe "should change(actual, message).by(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by expected amount" do
    lambda { @instance.some_value += 1 }.should change(@instance, :some_value).by(1)
  end

  it "should fail when the attribute is changed by unexpected amount" do
    lambda do
      lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by(1)
    end.should fail_with("some_value should have been changed by 1, but was changed by 2")
  end

  it "should fail when the attribute is changed by unexpected amount in the opposite direction" do
    lambda do
      lambda { @instance.some_value -= 1 }.should change(@instance, :some_value).by(1)
    end.should fail_with("some_value should have been changed by 1, but was changed by -1")
  end
end

describe "should change{ block }.by(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by expected amount" do
    lambda { @instance.some_value += 1 }.should change{@instance.some_value}.by(1)
  end

  it "should fail when the attribute is changed by unexpected amount" do
    lambda do
      lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by(1)
    end.should fail_with("result should have been changed by 1, but was changed by 2")
  end

  it "should fail when the attribute is changed by unexpected amount in the opposite direction" do
    lambda do
      lambda { @instance.some_value -= 1 }.should change{@instance.some_value}.by(1)
    end.should fail_with("result should have been changed by 1, but was changed by -1")
  end
end

describe "should change(actual, message).by_at_least(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by greater than the expected amount" do
    lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by_at_least(1)
  end
  
  it "should pass when attribute is changed by the expected amount" do
    lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by_at_least(2)
  end  

  it "should fail when the attribute is changed by less than the expected amount" do
    lambda do
      lambda { @instance.some_value += 1 }.should change(@instance, :some_value).by_at_least(2)
    end.should fail_with("some_value should have been changed by at least 2, but was changed by 1")
  end

end

describe "should change{ block }.by_at_least(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by greater than expected amount" do
    lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by_at_least(1)
  end
  
  it "should pass when attribute is changed by the expected amount" do
    lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by_at_least(2)
  end  

  it "should fail when the attribute is changed by less than the unexpected amount" do
    lambda do
      lambda { @instance.some_value += 1 }.should change{@instance.some_value}.by_at_least(2)
    end.should fail_with("result should have been changed by at least 2, but was changed by 1")
  end
end


describe "should change(actual, message).by_at_most(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by less than the expected amount" do
    lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by_at_most(3)
  end
  
  it "should pass when attribute is changed by the expected amount" do
    lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by_at_most(2)
  end  

  it "should fail when the attribute is changed by greater than the expected amount" do
    lambda do
      lambda { @instance.some_value += 2 }.should change(@instance, :some_value).by_at_most(1)
    end.should fail_with("some_value should have been changed by at most 1, but was changed by 2")
  end

end

describe "should change{ block }.by_at_most(expected)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 5
  end

  it "should pass when attribute is changed by less than expected amount" do
    lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by_at_most(3)
  end
  
  it "should pass when attribute is changed by the expected amount" do
    lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by_at_most(2)
  end  

  it "should fail when the attribute is changed by greater than the unexpected amount" do
    lambda do
      lambda { @instance.some_value += 2 }.should change{@instance.some_value}.by_at_most(1)
    end.should fail_with("result should have been changed by at most 1, but was changed by 2")
  end
end

describe "should change(actual, message).from(old)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end

  it "should pass when attribute is == to expected value before executing block" do
    lambda { @instance.some_value = "astring" }.should change(@instance, :some_value).from("string")
  end

  it "should fail when attribute is not == to expected value before executing block" do
    lambda do
      lambda { @instance.some_value = "knot" }.should change(@instance, :some_value).from("cat")
    end.should fail_with("some_value should have initially been \"cat\", but was \"string\"")
  end
end

describe "should change{ block }.from(old)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end

  it "should pass when attribute is == to expected value before executing block" do
    lambda { @instance.some_value = "astring" }.should change{@instance.some_value}.from("string")
  end

  it "should fail when attribute is not == to expected value before executing block" do
    lambda do
      lambda { @instance.some_value = "knot" }.should change{@instance.some_value}.from("cat")
    end.should fail_with("result should have initially been \"cat\", but was \"string\"")
  end
end

describe "should change(actual, message).to(new)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end
  
  it "should pass when attribute is == to expected value after executing block" do
    lambda { @instance.some_value = "cat" }.should change(@instance, :some_value).to("cat")
  end

  it "should fail when attribute is not == to expected value after executing block" do
    lambda do
      lambda { @instance.some_value = "cat" }.should change(@instance, :some_value).from("string").to("dog")
    end.should fail_with("some_value should have been changed to \"dog\", but is now \"cat\"")
  end
end

describe "should change{ block }.to(new)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end
  
  it "should pass when attribute is == to expected value after executing block" do
    lambda { @instance.some_value = "cat" }.should change{@instance.some_value}.to("cat")
  end

  it "should fail when attribute is not == to expected value after executing block" do
    lambda do
      lambda { @instance.some_value = "cat" }.should change{@instance.some_value}.from("string").to("dog")
    end.should fail_with("result should have been changed to \"dog\", but is now \"cat\"")
  end
end

describe "should change(actual, message).from(old).to(new)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end
  
  it "should pass when #to comes before #from" do
    lambda { @instance.some_value = "cat" }.should change(@instance, :some_value).to("cat").from("string")
  end

  it "should pass when #from comes before #to" do
    lambda { @instance.some_value = "cat" }.should change(@instance, :some_value).from("string").to("cat")
  end
end

describe "should change{ block }.from(old).to(new)" do
  before(:each) do
    @instance = SomethingExpected.new
    @instance.some_value = 'string'
  end
  
  it "should pass when #to comes before #from" do
    lambda { @instance.some_value = "cat" }.should change{@instance.some_value}.to("cat").from("string")
  end

  it "should pass when #from comes before #to" do
    lambda { @instance.some_value = "cat" }.should change{@instance.some_value}.from("string").to("cat")
  end
end

describe Spec::Matchers::Change do
  it "should work when the receiver has implemented #send" do
    @instance = SomethingExpected.new
    @instance.some_value = "string"
    def @instance.send(*args); raise "DOH! Library developers shouldn't use #send!" end
    
    lambda {
      lambda { @instance.some_value = "cat" }.should change(@instance, :some_value)
    }.should_not raise_error
  end
end
