$:.push File.join(File.dirname(__FILE__), *%w[.. .. lib])
require 'spec'

class AdditionMatchers < Spec::Story::StepGroup
  steps do |add|
    add.given("an addend of $addend") do |addend|
      @adder ||= Adder.new
      @adder << addend.to_i
    end
  end
end

steps = AdditionMatchers.new do |add|  
  add.then("the sum should be $sum") do |sum|
    @sum.should == sum.to_i
  end
end

steps.when("they are added") do
  @sum = @adder.sum
end

# This Story uses steps (see above) instead of blocks
# passed to Given, When and Then

Story "addition", %{
  As an accountant
  I want to add numbers
  So that I can count some beans
}, :steps_for => steps do
  Scenario "2 + 3" do
    Given "an addend of 2"
    And "an addend of 3"
    When "they are added"
    Then "the sum should be 5"
  end
  
  # This scenario uses GivenScenario, which silently runs
  # all the steps in a previous scenario.
  
  Scenario "add 4 more" do
    GivenScenario "2 + 3"
    Given "an addend of 4"
    When "they are added"
    Then "the sum should be 9"
  end
end

# And the class that makes the story pass

class Adder
  def << addend
    addends << addend
  end
  
  def sum
    @addends.inject(0) do |result, addend|
      result + addend.to_i
    end
  end
  
  def addends
    @addends ||= []
  end
end
