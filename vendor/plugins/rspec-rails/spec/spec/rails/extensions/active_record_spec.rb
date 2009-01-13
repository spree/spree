require File.dirname(__FILE__) + '/../../../spec_helper'

describe "A model" do
  fixtures :things
  it "should tell you its required fields" do
    Thing.new.should have(1).error_on(:name)
  end
  
  it "should tell you how many records it has" do
    Thing.should have(:no).records
    Thing.create(:name => "THE THING")
    Thing.should have(1).record
  end
end
