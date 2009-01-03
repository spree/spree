rspec_lib = File.dirname(__FILE__) + "/../../../../../../lib"
$:.unshift rspec_lib unless $:.include?(rspec_lib)
require 'test/unit'
require 'spec'

describe "options hash" do
  describe "#options" do
    it "should expose the options hash" do
      group = describe("group", :this => 'hash') {}
      group.options[:this].should == 'hash'
    end
  end
end