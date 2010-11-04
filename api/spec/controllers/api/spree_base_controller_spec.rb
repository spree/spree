require 'spec_helper.rb'

# Its difficult to test the Api::BaseController in the abstract since rspec insists on having legit routes, etc.
# So we'll test against Api::OrdersController instead as a reprentative controller
describe Api::OrdersController do
  let(:user) { mock_model User }

  context "#current_user" do

    # context "when header includes a legit api key" do
    #   it "should reutrn the matching user" do
    #     request.env['X-SpreeAPIKey'] = "legit"
    #     User.should_receive(:find_by_api_key).with("legit").and_return user
    #     put :index
    #   end
    # end
    # context "when header includes a bogus api key" do
    #   before { User.stub :find_by_api_key => nil }
    #   it "should return nil" do
    #     request.env['X-SpreeAPIKey'] = "bogus"
    #     User.should_receive(:find_by_api_key).with("bogus").and_return nil
    #     put :index
    #   end
    # end
  end

  #before { Order.stub :find_by_id => mock_model(Order) }

  shared_examples_for "access granted" do
    it "should allow index" do
      get :index, :format => :json
      response.should be_success
    end
    it "should allow read" do
      get :show, {:id => 1}, :format => :json
      response.should be_success
    end
    # it "should allow create"
    # it "should allow update"
    # it "should allow destroy"
  end

  shared_examples_for "access denied" do
    it "should not allow index" do
      get :index, :format => :json
      response.code.should == "401"
    end
    it "should not allow read" do
      get :show, {:id => 1}, :format => :json
      response.code.should == "401"
    end
    # it "should allow create"
    # it "should allow update"
    # it "should allow destroy"
  end

  context "when correct api key passed in header" do
    before do
      request.env['X-SpreeAPIKey'] = "legit"
      User.should_receive(:find_by_api_key).with("legit").and_return user
    end
    it_should_behave_like "access granted"
  end

  context "when api key is missing from header" do
    it_should_behave_like "access denied"
  end

  context "when incorrect api key passed in header" do
    before do
      request.env['X-SpreeAPIKey'] = "fail"
      User.should_receive(:find_by_api_key).with("fail").and_return nil
    end
    it_should_behave_like "access denied"
  end

end

