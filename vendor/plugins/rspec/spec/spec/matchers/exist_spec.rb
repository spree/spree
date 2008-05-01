require File.dirname(__FILE__) + '/../../spec_helper.rb'

class Substance
  def initialize exists, description
    @exists = exists
    @description = description
  end
  def exist?
    @exists
  end
  def inspect
    @description
  end
end
  
class SubstanceTester
  include Spec::Matchers
  def initialize substance
    @substance = substance
  end
  def should_exist
    @substance.should exist
  end
end

describe "should exist," do
  
  before(:each) do
    @real = Substance.new true, 'something real'
    @imaginary = Substance.new false, 'something imaginary'
  end

  describe "within an example group" do
  
    it "should pass if target exists" do
      @real.should exist
    end
  
    it "should fail if target does not exist" do
      lambda { @imaginary.should exist }.should fail
    end
    
    it "should pass if target doesn't exist" do
      lambda { @real.should_not exist }.should fail
    end
  end

  describe "outside of an example group" do

    it "should pass if target exists" do
      real_tester = SubstanceTester.new @real
      real_tester.should_exist
    end

  end

end
