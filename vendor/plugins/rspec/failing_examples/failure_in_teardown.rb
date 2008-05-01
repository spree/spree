describe "This example" do
  
  it "should be listed as failing in teardown" do
  end
  
  after(:each) do
    NonExistentClass.new
  end
  
end
