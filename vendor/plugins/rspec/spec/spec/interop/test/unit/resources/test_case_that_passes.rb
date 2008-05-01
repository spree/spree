rspec_lib = File.dirname(__FILE__) + "/../../../../../../lib"
$:.unshift rspec_lib unless $:.include?(rspec_lib)
require 'test/unit'
require 'spec'

class TestCaseThatPasses < Test::Unit::TestCase
  def test_that_passes
    true.should be_true
  end
end