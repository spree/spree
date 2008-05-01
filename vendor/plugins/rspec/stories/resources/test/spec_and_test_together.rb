$:.push File.join(File.dirname(__FILE__), *%w[.. .. .. lib])
require 'spec'
# TODO - this should not be necessary, ay?
require 'spec/interop/test'

describe "An Example" do
  it "should pass with assert" do
    assert true
  end

  it "should fail with assert" do
    assert false
  end

  it "should pass with should" do
    1.should == 1
  end

  it "should fail with should" do
    1.should == 2
  end
end

class ATest < Test::Unit::TestCase
  def test_should_pass_with_assert
    assert true
  end
  
  def test_should_fail_with_assert
    assert false
  end

  def test_should_pass_with_should
    1.should == 1
  end
  
  def test_should_fail_with_should
    1.should == 2
  end

  def setup
    @from_setup ||= 3
    @from_setup += 1
  end

  def test_should_fail_with_setup_method_variable
    @from_setup.should == 40
  end

  before do
    @from_before = @from_setup + 1
  end

  def test_should_fail_with_before_block_variable
    @from_before.should == 50
  end
end