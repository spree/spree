require File.dirname(__FILE__) + '/spec_helper'
$global = 0

describe "State created in before(:all)" do
  before :all do
    @sideeffect = 1
    $global +=1
  end

  before :each do
    @isolated = 1
  end
  
  it "should be accessible from example" do
    @sideeffect.should == 1
    $global.should == 1
    @isolated.should == 1

    @sideeffect += 1
    @isolated += 1
  end

  it "should not have sideffects" do
    @sideeffect.should == 1
    $global.should == 2
    @isolated.should == 1

    @sideeffect += 1
    @isolated += 1
  end

  after :each do
    $global += 1
  end
  
  after :all do
    $global.should == 3
    $global = 0
  end
end
