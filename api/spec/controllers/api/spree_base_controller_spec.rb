require 'spec_helper.rb'

# Its difficult to test the Api::BaseController in the abstract since rspec insists on having legit routes, etc.
# So we'll test against Api::OrdersController instead as a reprentative controller
describe Api::OrdersController do
  context "#current_user" do
    let(:user) { mock_model User }
    context "when header includes a legit api key" do
      it "should reutrn the matching user" do
        request.env['X-SpreeAPIKey'] = "legit"
        User.should_receive(:find_by_api_key).with("legit").and_return user
        put :index
      end
    end
    context "when header includes a bogus api key" do
      before { User.stub :find_by_api_key => nil }
      it "should return nil" do
        request.env['X-SpreeAPIKey'] = "bogus"
        User.should_receive(:find_by_api_key).with("bogus").and_return nil
        put :index
      end
    end
  end
end

