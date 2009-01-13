require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "PreferenceDefinition by default" do
  before(:each) do
    @definition = Spree::Preferences::PreferenceDefinition.new(:notifications)
  end

  it "should have an attribute" do
    @definition.attribute.should == "notifications"
  end

  it "should not have a default value" do
    @definition.default_value.should be_nil
  end

  it "should type_cast values as booleans" do
    @definition.type_cast(nil).should be_nil
    @definition.type_cast(true).should be_true
    @definition.type_cast(false).should be_false
    @definition.type_cast(0).should be_false
    @definition.type_cast(1).should be_true
  end
end

describe "PreferenceDefinition" do
  it "should raise an exception on invalid options specified" do
    lambda {Spree::Preferences::PreferenceDefinition.new(:notifications, :invalid => true)}.should raise_error(ArgumentError)
  end
end

describe "PreferenceDefinition with :any type" do
  before(:each) do
    @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :any)
  end

  it "should not type_cast" do
    @definition.type_cast(nil).should be_nil
    @definition.type_cast(0).should == 0
    @definition.type_cast(1).should == 1
    @definition.type_cast(false).should be_false
    @definition.type_cast(true).should be_true
    @definition.type_cast('').should == ''
    @definition.type_cast('Chunky bacon').should == 'Chunky bacon'
  end

  it "should query false if value is nil" do
    @definition.query(nil).should be_false
  end

  it "should query true if value is zero" do
    @definition.query(0).should be_true
  end

  it "should query true if value es not zero" do
    @definition.query(-1).should be_true
    @definition.query(1).should be_true
  end

  it "should query false if value is blank" do
    @definition.query('').should be_false
  end

  it "should query true if value is not blank" do
    @definition.query('hello').should be_true
  end
end

describe "PreferenceDefinition with :boolean default value" do
  it "should type_cast default values" do
    definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :boolean, :default => 1)
    definition.default_value.should be_true
  end
end

describe "PreferenceDefinition with :boolean type" do
  before(:each) do
    @definition = Spree::Preferences::PreferenceDefinition.new(:notifications)
  end

  it "should not type_cast if value is nil" do
    @definition.type_cast(nil).should be_nil
  end

  it "should type_cast to false if value is not 1" do
    @definition.type_cast(0).should be_false
    @definition.type_cast(3).should be_false
  end

  it "should type_cast to true if value is 1" do
    @definition.type_cast(1).should be_true
  end

  it "should type_cast to ture if value is true string" do
    @definition.type_cast('true').should be_true
  end

  it "should type_cast to false if value is not true string" do
    @definition.type_cast('false').should be_false
    @definition.type_cast('hola').should be_false
  end

  it "should query false if value is nil" do
    @definition.query(nil).should be_false
  end

  it "should query true if value is 1" do
    @definition.query(1).should be_true
  end

  it "should query false if value es not 1" do
    @definition.query(-1).should be_false
    @definition.query(0).should be_false
  end

  it "should query true if value is true string" do
    @definition.query('true').should be_true
  end

  it "should query false if value is not true string" do
    @definition.query('').should be_false
  end
end

describe "PreferenceDefinition with Numeric type" do
  before(:each) do
    @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :integer)
  end

  it "should type_cast true to integer" do
    @definition.type_cast(true).should == 1
  end

  it "should type_cast false to integer" do
    @definition.type_cast(false).should == 0
  end

  it "should type_cast string to integer" do
    @definition.type_cast('hello').should == 0
    @definition.type_cast('1').should == 1
  end

  it "should query false if value is nil" do
    @definition.query(nil).should be_false
  end

  it "should query true if value is 1" do
    @definition.query(1).should be_true
  end

  it "should query false if value is 0" do
    @definition.query(0).should be_false
  end
end

describe "PreferenceDefinition with String type" do
  before(:each) do
    @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :string)
  end

  it "should type_cast integer to strings" do
    @definition.type_cast('1').should == '1'
  end

  it "should not type_cast booleans" do
    @definition.type_cast(true).should be_true
    @definition.type_cast(false).should be_false
  end

  it "should query true if value is 1" do
    @definition.query(1).should be_true
  end

  it "should query true if value is zero" do
    @definition.query(0).should be_true
  end

  it "should query false if value is blank" do
    @definition.query('').should be_false
  end

  it "should query true if value is not blank" do
    @definition.query('hello').should be_true
  end
end
