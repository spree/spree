require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe AppConfiguration do
  before(:each) do
    @valid_attributes = {
      :name => "Default Configuration"
    }
  end

  it "should create a new instance given valid attributes" do
    AppConfiguration.create!(@valid_attributes)
  end
end
