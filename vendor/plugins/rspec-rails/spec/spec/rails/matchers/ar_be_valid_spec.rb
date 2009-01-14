require File.dirname(__FILE__) + '/../../../spec_helper'

describe "be_valid" do
  class CanBeValid
    def initialize(valid)
      @valid = valid
    end
    def valid?; @valid end
  end

  it "should behave like normal be_valid matcher" do
    CanBeValid.new(true).should be_valid
    CanBeValid.new(false).should_not be_valid
  end

  class CanHaveErrors
    def initialize(errors)
      @valid = !errors
      @errors = ActiveRecord::Errors.new self
      @errors.add :name, "is too short"
    end
    attr_reader :errors
    def valid?; @valid end

    def self.human_attribute_name(ignore)
      "Name"
    end
  end

  it "should show errors in the output if they're available" do
    lambda { 
      CanHaveErrors.new(true).should be_valid
    }.should fail_with(/Name is too short/)
  end
end
