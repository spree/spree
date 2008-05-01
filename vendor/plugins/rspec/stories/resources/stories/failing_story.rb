$:.push File.join(File.dirname(__FILE__), *%w[.. .. .. lib])

require 'spec/story'

Story "Failing story",
%(As an RSpec user
  I want a failing test
  So that I can observe the output) do

  Scenario "Failing scenario" do
    Then "true should be false" do
      true.should == false
    end
  end
end
