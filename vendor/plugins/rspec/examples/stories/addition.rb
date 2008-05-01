require File.join(File.dirname(__FILE__), "helper")
require File.join(File.dirname(__FILE__), "adder")

# with_steps_for :addition, :more_addition do
with_steps_for :addition, :more_addition do
  # Then("the corks should be popped") { }
  run File.expand_path(__FILE__).gsub(".rb","")
end

