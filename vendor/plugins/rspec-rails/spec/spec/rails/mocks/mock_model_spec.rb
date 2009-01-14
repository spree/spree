require File.dirname(__FILE__) + '/../../../spec_helper'
require File.dirname(__FILE__) + '/ar_classes'

describe "mock_model" do
  describe "responding to interrogation" do
    before(:each) do
      @model = mock_model(SubMockableModel)
    end
    it "should say it is_a? if it is" do
      @model.is_a?(SubMockableModel).should be(true)
    end
    it "should say it is_a? if it's ancestor is" do
      @model.is_a?(MockableModel).should be(true)
    end
    it "should say it is kind_of? if it is" do
      @model.kind_of?(SubMockableModel).should be(true)
    end
    it "should say it is kind_of? if it's ancestor is" do
      @model.kind_of?(MockableModel).should be(true)
    end
    it "should say it is instance_of? if it is" do
      @model.instance_of?(SubMockableModel).should be(true)
    end
    it "should not say it instance_of? if it isn't, even if it's ancestor is" do
      @model.instance_of?(MockableModel).should be(false)
    end
  end

  describe "with params" do
    it "should not mutate its parameters" do
      params = {:a => 'b'}
      model = mock_model(MockableModel, params)
      params.should == {:a => 'b'}
    end
  end

  describe "with #id stubbed", :type => :view do
    before(:each) do
      @model = mock_model(MockableModel, :id => 1)
    end
    it "should be named using the stubbed id value" do
      @model.instance_variable_get(:@name).should == "MockableModel_1"
    end
    it "should return string of id value for to_param" do
      @model.to_param.should == "1"
    end
  end

  describe "as association", :type => :view do
    before(:each) do
      @real = AssociatedModel.create!
      @mock_model = mock_model(MockableModel)
      @real.mockable_model = @mock_model
    end

    it "should pass associated_model == mock" do
        @mock_model.should == @real.mockable_model
    end

    it "should pass mock == associated_model" do
        @real.mockable_model.should == @mock_model
    end
  end

  describe "with :null_object => true", :type => :view do
    before(:each) do
      @model = mock_model(MockableModel, :null_object => true, :mocked_method => "mocked")
    end

    it "should be able to mock methods" do
      @model.mocked_method.should == "mocked"
    end
    it "should return itself to unmocked methods" do
      @model.unmocked_method.should equal(@model)
    end
  end

  describe "#as_null_object", :type => :view do
    before(:each) do
      @model = mock_model(MockableModel, :mocked_method => "mocked").as_null_object
    end

    it "should be able to mock methods" do
      @model.mocked_method.should == "mocked"
    end
    it "should return itself to unmocked methods" do
      @model.unmocked_method.should equal(@model)
    end
  end

  describe "#as_new_record" do
    it "should say it is a new record" do
      mock_model(MockableModel).as_new_record.should be_new_record
    end

    it "should have a nil id" do
      mock_model(MockableModel).as_new_record.id.should be(nil)
    end

    it "should return nil for #to_param" do
      mock_model(MockableModel).as_new_record.to_param.should be(nil)
    end
  end
end


