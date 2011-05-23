require 'spec_helper.rb'

# Its difficult to test the Api::BaseController in the abstract since rspec insists on having legit routes, etc.
# So we'll test against Api::OrdersController instead as a reprentative controller
describe Api::OrdersController do
  let(:user) { mock_model(User, :has_role? => true) }
  before { controller.stub :current_user => user }

  shared_examples_for "access granted" do
    it "should allow index" do
      get :index, :format => :json
      response.should be_success
    end
    it "should allow read" do
      get :show, {:id => 1}, :format => :json
      response.should be_success
    end
    # it "should allow update"
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
    # it "should not allow update"
  end

  context "when correct HTTP_AUTHORIZATION" do
    before do
      request.env['HTTP_AUTHORIZATION'] = "legit:x"
    end
    it "should allow index" do
      get :index, :format => :json
      response.code.should == "200"
    end
  end

  context "when authenticated as admin" do
  end

  context "when no HTTP_AUTHORIZATION" do
    it_should_behave_like "access denied"
    context "when authenticated as admin" do
      it_should_behave_like "access denied"
    end
  end

end
