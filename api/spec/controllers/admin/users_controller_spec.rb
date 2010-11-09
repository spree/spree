require 'spec_helper'

describe Admin::UsersController do

  let(:user) { mock_model User }

  before do
    controller.stub :current_user => mock_model(User, :has_role? => true)
    User.stub :find => user
  end

  context "#generate_api_key" do
    it "should generate a 40 char key" do
      user.should_receive :generate_api_key!
      put :generate_api_key, {:id => 1}
    end
  end

  context "#clear_api_key" do
    it "should clear the key" do
      user.stub :key => "FOOFAH"
      user.should_receive :clear_api_key!
      put :clear_api_key, {:id => 1}
    end
  end

end