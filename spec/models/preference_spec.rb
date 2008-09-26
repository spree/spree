require File.dirname(__FILE__) + '/../spec_helper'

include PreferenceFactory

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

  it "should be able to split ActiveRecord groups" do
    user = mock_model(Product)
    group_id, group_type = Preference.split_group(user)
    group_id.should == user.id
    group_type.should == 'Product'
  end
end
# -- See Issue #86
=begin
describe Preference, "after being created" do  
  before(:each) do
    User.preference :notifications, :boolean
    @preference = new_preference
  end
  
  it "should have an owner" do
    @preference.owner.should_not be_nil
  end
  
  it "should have a definition" do
    @preference.definition.should_not be_nil
  end
  
  it "should have a value" do
    @preference.value.should_not be_nil
  end
  
  it "should not have a group association" do
    @preference.group.should be_nil
  end

  after(:each) do
    User.preference_definitions.delete('notifications')
    User.default_preferences.delete('notifications')
  end
end
=end

describe Preference, "in general" do
  it "should be valid with valid attributes" do
    preference = new_preference
    preference.should be_valid
  end

  it "should require an attribute" do
    preference = new_preference(:attribute => nil)
    preference.should_not be_valid
    preference.errors_on(:attribute).length.should == 1
  end
  
  it "should have an owner_id and owner_type" do
    preference = new_preference(:owner => nil)
    preference.should_not be_valid
    preference.errors_on(:owner_id).length.should == 1
    preference.errors_on(:owner_type).length.should == 1
  end

  it "should not require a group" do
    preference = new_preference(:group => nil)
    preference.should be_valid
  end
  
  it "should not require a group_id even when a group_type is specified" do
    preference = new_preference(:group => nil)
    preference.group_type = 'Product'
    preference.should be_valid
  end

  it "should require a group type when a group_id is specified" do
    preference = new_preference(:group => nil)
    preference.group_id = 1
    preference.should_not be_valid
    preference.errors_on(:group_type).length.should == 1
  end
end

describe Preference, "with basic group" do
  it "should have a group association" do
    preference = create_preference(:group_type => 'car')
    preference.group.should == 'car'
  end
end

describe Preference, "with ActiveRecord group" do
  it "should have a group association" do
    product = create_product
    preference = create_preference(:group => product)
    preference.group.should == product
  end
end

# -- See Issue #86
=begin
describe Preference, "with boolean attribute" do
  before(:each) do
    User.preference :notifications, :boolean
    @preference = new_preference(:attribute => 'notifications', :value => nil)
  end

  it "should type_cast nil values" do
    @preference.value.should be_nil
  end

  it "should type_cast numeric values" do
    @preference.value = 0
    @preference.value.should be_false
    @preference.value = 1
    @preference.value.should be_true
    @preference.value = 3
    @preference.value.should be_false
  end

  it "should type_cast boolean values" do
    @preference.value = false
    @preference.value.should be_false
    @preference.value = true
    @preference.value.should be_true
  end

  it "should type_cast string values" do
    @preference.value = "false"
    @preference.value.should be_false
    @preference.value = "true"
    @preference.value.should be_true
    @preference.value = "hello"
    @preference.value.should be_false
  end

  after(:each) do
    User.preference_definitions.delete('notifications')
    User.default_preferences.delete('notifications')
  end
end
=end