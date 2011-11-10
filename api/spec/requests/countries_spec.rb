require 'spec_helper'

describe "States" do
  context "GET" do
    context "with an authorized api user" do
      before(:each) do
        Factory(:country)
        @user = Factory(:admin_user)
        api_login(@user)
        get "/api/countries", :format => :json
      end

      it_should_behave_like "status ok"

      it "should retrieve an array of 100 countries" do
        page = JSON.load(last_response.body)
        page.map { |d| d['name'] }.length.should == 1.to_i
        page.first.keys.sort.should == ["country"]

        keys = ["id", "iso", "iso3", "iso_name", "name", "numcode"]
        page.first['country'].keys.sort.should == keys
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        get "/api/countries", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
