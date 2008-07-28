require File.dirname(__FILE__) + '/../../spec_helper'
require File.dirname(__FILE__) + '/ar_classes'

describe "stub_model" do
  describe "defaults" do
    it "should have an id" do
      stub_model(MockableModel).id.should be > 0
    end
  
    it "should say it is not a new record" do
      stub_model(MockableModel).should_not be_new_record
    end
  end
  
  it "should accept a stub id" do
    stub_model(MockableModel, :id => 37).id.should == 37
  end
  
  it "should say it is a new record when id is set to nil" do
    stub_model(MockableModel, :id => nil).should be_new_record
  end
  
  it "should accept any arbitrary stub" do
    stub_model(MockableModel, :foo => "bar").foo.should == "bar"
  end
  
  it "should accept a stub for save" do
    stub_model(MockableModel, :save => false).save.should be(false)
  end
  
  describe "#as_new_record" do
    it "should say it is a new record" do
      stub_model(MockableModel).as_new_record.should be_new_record
    end

    it "should have a nil id" do
      stub_model(MockableModel).as_new_record.id.should be(nil)
    end
  end
  
  it "should raise when hitting the db" do
    lambda do
      model = stub_model(MockableModel, :changed => true, :attributes_with_quotes => {'this' => 'that'})
      model.save
    end.should raise_error(Spec::Rails::IllegalDataAccessException, /stubbed models are not allowed to access the database/)
  end
  
  it "should increment the id" do
    first = stub_model(MockableModel)
    second = stub_model(MockableModel)
    second.id.should == (first.id + 1)
  end
  
end

describe "stub_model as association" do
  before(:each) do
    @real = AssociatedModel.create!
    @stub_model = stub_model(MockableModel)
    @real.mockable_model = @stub_model
  end
  
  it "should pass associated_model == mock" do
      @stub_model.should == @real.mockable_model
  end

  it "should pass mock == associated_model" do
      @real.mockable_model.should == @stub_model
  end
end

describe "stub_model with a block" do
  it "should yield the model" do
    model = stub_model(MockableModel) do |block_arg|
      @block_arg = block_arg
    end
    model.should be(@block_arg)
  end
end
