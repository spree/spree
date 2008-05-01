require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "ExecutionContext" do
  
  it "should provide duck_type()" do
    dt = duck_type(:length)
    dt.should be_an_instance_of(Spec::Mocks::DuckTypeArgConstraint)
    dt.matches?([]).should be_true
  end

  it "should violate when violated()" do
    lambda do
      violated
    end.should raise_error(Spec::Expectations::ExpectationNotMetError)
  end

  it "should provide mock()" do
    mock("thing").should be_an_instance_of(Spec::Mocks::Mock)
  end

  it "should provide stub()" do
    thing_stub = stub("thing").should be_an_instance_of(Spec::Mocks::Mock)
  end
  
  it "should add method stubs to stub()" do
    thing_stub = stub("thing", :a => "A", :b => "B")
    thing_stub.a.should == "A"
    thing_stub.b.should == "B"
  end

end
