rspec_lib = File.dirname(__FILE__) + "/../../../../../../lib"
$:.unshift rspec_lib unless $:.include?(rspec_lib)
require 'test/unit'
require 'spec'

describe "example group with errors" do
  it "should raise errors" do
    raise "error raised in example group with errors"
  end
end