require File.dirname(__FILE__) + '/../../spec_helper.rb'

require 'spec/expectations/differs/default'

describe "should ==" do
  
  it "should delegate message to target" do
    subject = "apple"
    subject.should_receive(:==).with("apple").and_return(true)
    subject.should == "apple"
  end
  
  it "should fail when target.==(actual) returns false" do
    subject = "apple"
    Spec::Expectations.should_receive(:fail_with).with(%[expected: "orange",\n     got: "apple" (using ==)], "orange", "apple")
    subject.should == "orange"
  end

end

describe "should_not ==" do
  
  it "should delegate message to target" do
    subject = "orange"
    subject.should_receive(:==).with("apple").and_return(false)
    subject.should_not == "apple"
  end
  
  it "should fail when target.==(actual) returns false" do
    subject = "apple"
    Spec::Expectations.should_receive(:fail_with).with(%[expected not: == "apple",\n         got:    "apple"], "apple", "apple")
    subject.should_not == "apple"
  end

end

describe "should ===" do
  
  it "should delegate message to target" do
    subject = "apple"
    subject.should_receive(:===).with("apple").and_return(true)
    subject.should === "apple"
  end
  
  it "should fail when target.===(actual) returns false" do
    subject = "apple"
    subject.should_receive(:===).with("orange").and_return(false)
    Spec::Expectations.should_receive(:fail_with).with(%[expected: "orange",\n     got: "apple" (using ===)], "orange", "apple")
    subject.should === "orange"
  end
  
end

describe "should_not ===" do
  
  it "should delegate message to target" do
    subject = "orange"
    subject.should_receive(:===).with("apple").and_return(false)
    subject.should_not === "apple"
  end
  
  it "should fail when target.===(actual) returns false" do
    subject = "apple"
    subject.should_receive(:===).with("apple").and_return(true)
    Spec::Expectations.should_receive(:fail_with).with(%[expected not: === "apple",\n         got:     "apple"], "apple", "apple")
    subject.should_not === "apple"
  end

end

describe "should =~" do
  
  it "should delegate message to target" do
    subject = "foo"
    subject.should_receive(:=~).with(/oo/).and_return(true)
    subject.should =~ /oo/
  end
  
  it "should fail when target.=~(actual) returns false" do
    subject = "fu"
    subject.should_receive(:=~).with(/oo/).and_return(false)
    Spec::Expectations.should_receive(:fail_with).with(%[expected: /oo/,\n     got: "fu" (using =~)], /oo/, "fu")
    subject.should =~ /oo/
  end

end

describe "should_not =~" do
  
  it "should delegate message to target" do
    subject = "fu"
    subject.should_receive(:=~).with(/oo/).and_return(false)
    subject.should_not =~ /oo/
  end
  
  it "should fail when target.=~(actual) returns false" do
    subject = "foo"
    subject.should_receive(:=~).with(/oo/).and_return(true)
    Spec::Expectations.should_receive(:fail_with).with(%[expected not: =~ /oo/,\n         got:    "foo"], /oo/, "foo")
    subject.should_not =~ /oo/
  end

end

describe "should >" do
  
  it "should pass if > passes" do
    4.should > 3
  end

  it "should fail if > fails" do
    Spec::Expectations.should_receive(:fail_with).with(%[expected: > 5,\n     got:   4], 5, 4)
    4.should > 5
  end

end

describe "should >=" do
  
  it "should pass if >= passes" do
    4.should > 3
    4.should >= 4
  end

  it "should fail if > fails" do
    Spec::Expectations.should_receive(:fail_with).with(%[expected: >= 5,\n     got:    4], 5, 4)
    4.should >= 5
  end

end

describe "should <" do
  
  it "should pass if < passes" do
    4.should < 5
  end

  it "should fail if > fails" do
    Spec::Expectations.should_receive(:fail_with).with(%[expected: < 3,\n     got:   4], 3, 4)
    4.should < 3
  end

end

describe "should <=" do
  
  it "should pass if <= passes" do
    4.should <= 5
    4.should <= 4
  end

  it "should fail if > fails" do
    Spec::Expectations.should_receive(:fail_with).with(%[expected: <= 3,\n     got:    4], 3, 4)
    4.should <= 3
  end

end

