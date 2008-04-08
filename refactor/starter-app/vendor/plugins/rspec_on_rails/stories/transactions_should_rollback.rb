require File.join(File.dirname(__FILE__), *%w[helper])

Story "transactions should rollback", %{
  As an RSpec/Rails Story author
  I want transactions to roll back between scenarios
  So that I can have confidence in the state of the database
}, :type => RailsStory do
  Scenario "add one Person" do
    When "I add a Person" do
      Person.create!(:name => "Foo")
    end
  end
  
  Scenario "add another person" do
    GivenScenario "add one Person"
    Then "there should be one person" do
      Person.count.should == 1
    end
  end

  Scenario "add yet another person" do
    GivenScenario "add one Person"
    Then "there should be one person"
  end
end