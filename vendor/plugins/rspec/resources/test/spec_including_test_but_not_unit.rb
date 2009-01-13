$:.push File.join(File.dirname(__FILE__), *%w[.. .. lib])
require 'spec'

module Test
end

describe "description" do
  it "should description" do
    1.should == 1
  end
end