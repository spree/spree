require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should include(expected)" do
  it "should pass if target includes expected" do
    [1,2,3].should include(3)
    "abc".should include("a")
  end
  
  it 'should pass if target is a Hash and has the expected as a key' do
    {:key => 'value'}.should include(:key)
  end

  it "should fail if target does not include expected" do
    lambda {
      [1,2,3].should include(4)
    }.should fail_with("expected [1, 2, 3] to include 4")
    lambda {
      "abc".should include("d")
    }.should fail_with("expected \"abc\" to include \"d\"")
    lambda {
      {:key => 'value'}.should include(:other)
    }.should fail_with(%Q|expected {:key=>"value"} to include :other|)
  end
end

describe "should include(with, multiple, args)" do
  it "should pass if target includes all items" do
    [1,2,3].should include(1,2,3)
  end
  
  it 'should pass if target is a Hash including all items as keys' do
    {:key => 'value', :other => 'value'}.should include(:key, :other)
  end

  it "should fail if target does not include any one of the items" do
    lambda {
      [1,2,3].should include(1,2,4)
    }.should fail_with("expected [1, 2, 3] to include 1, 2 and 4")
  end
  
  it 'should pass if target is a Hash missing any item as a key' do
    lambda {
      {:key => 'value'}.should include(:key, :other)
    }.should fail_with(%Q|expected {:key=>"value"} to include :key and :other|)
  end
end

describe "should_not include(expected)" do
  it "should pass if target does not include expected" do
    [1,2,3].should_not include(4)
    "abc".should_not include("d")
  end
  
  it 'should pass if target is a Hash and does not have the expected as a key' do
    {:other => 'value'}.should_not include(:key)
  end

  it "should fail if target includes expected" do
    lambda {
      [1,2,3].should_not include(3)
    }.should fail_with("expected [1, 2, 3] not to include 3")
    lambda {
      "abc".should_not include("c")
    }.should fail_with("expected \"abc\" not to include \"c\"")
    lambda {
      {:key => 'value'}.should_not include(:key)
    }.should fail_with(%Q|expected {:key=>"value"} not to include :key|)
  end
end

describe "should include(:key => value)" do
  it "should pass if target is a Hash and includes the key/value pair" do
    {:key => 'value'}.should include(:key => 'value')
  end
  it "should pass if target is a Hash and includes the key/value pair among others" do
    {:key => 'value', :other => 'different'}.should include(:key => 'value')
  end
  it "should fail if target is a Hash and has a different value for key" do
    lambda {
      {:key => 'different'}.should include(:key => 'value')
    }.should fail_with(%Q|expected {:key=>"different"} to include {:key=>"value"}|)
  end
  it "should fail if target is a Hash and has a different key" do
    lambda {
      {:other => 'value'}.should include(:key => 'value')
    }.should fail_with(%Q|expected {:other=>"value"} to include {:key=>"value"}|)
  end
end
