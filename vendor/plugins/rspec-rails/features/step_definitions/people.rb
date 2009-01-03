When "I add a Person" do
  Person.create!(:name => "Foo")
end
Then "there should be one person" do
  Person.count.should == 1
end
