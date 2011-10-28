require 'spec_helper'

describe "States" do
  context "GET" do
    context "with an authorized api user" do
      context "retrieving a list of states" do
        before(:each) do
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/countries/#{State.last.country.id}/states", :format => :json
        end

        it_should_behave_like "status ok"

        it "should retrieve an array of 51 states" do
          page = JSON.load(last_response.body)
          page.map { |d| d['name'] }.length.should == 51.to_i
          page.first.keys.sort.should == ["state"]

          keys = ["abbr", "country_id", "id", "name"]
          page.first['state'].keys.sort.should == keys
        end
      end

      context "retrieving a specific state" do
        before(:each) do
          @user = Factory(:admin_user)
          api_login(@user)
          state = State.first
          get "/api/countries/#{state.country.id}/states/#{state.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return state information" do
          page = JSON.load(last_response.body)
          page['state']['abbr'].should  be_true
          page['state']['name'].should  be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        get "/api/countries/#{State.last.country.id}/states", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
