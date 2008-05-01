rspec_lib = File.dirname(__FILE__) + "/../../../../../../lib"
$:.unshift rspec_lib unless $:.include?(rspec_lib)
require 'test/unit'
require 'spec'

describe "example group with passing examples" do
  it "should pass" do
    true.should be_true
  end
end