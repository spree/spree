require File.dirname(__FILE__) + '/../spec_helper'

describe Preference, "by default" do
  before(:each) do
    @preference = Preference.new
  end

  it "should not have an attribute" do
    @preference.attribute.should be_blank
  end

  it "should not have an owner" do
    @preference.owner.should be_nil
  end

  it "should not have an owner type" do
    @preference.owner_type.should be_blank
  end

  it "should not have a group association" do
    @preference.group_id.should be_nil
  end

  it "should not have a group type" do
    @preference.group_type.should be_nil
  end

  it "should not have a value" do
    @preference.value.should be_blank
  end

  it "should not have a definition" do
    @preference.definition.should be_nil
  end
end

describe Preference, "as a Class" do
  it "should be able to split nil groups" do
    group_id, group_type = Preference.split_group(nil)
    group_id.should be_nil
    group_type.should be_nil
  end
  
  it "should be able to split non ActiveRecord groups" do
    group_id, group_type = Preference.split_group('car')
    group_id.should be_nil
    group_type.should == 'car'
  end
end

# describe Preference, "after being created" do
#   it "should have an owner"
#   it "should have a definition"
#   it "should have a value"
#   it "should not have a group association"
# end

# describe Preference, "in general" do
#   it "should be valid with valid attributes"
#   it "should require an attribute"
#   it "should have an owner"
#   it "should have an owner type"
#   it "should not require a group"
#   it "should not require a group even when a group type is specified"
#   it "should not require a group type"
#   it "should require a group type a group_id is specified"
# end
