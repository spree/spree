require 'spec_helper'

module Spree
  describe Api::StatesController do
    render_views

    let!(:state) { create(:state, :name => "Victoria") }
    let(:attributes) { [:id, :name, :abbr, :country_id] }

    before do
      stub_authentication!
    end

    it "gets all states" do
      api_get :index
      json_response["states"].first.should have_attributes(attributes)
      json_response['states'].first['name'].should eq(state.name)
    end

    context "pagination" do
      before do
        State.should_receive(:accessible_by).and_return(@scope = double)
        @scope.stub_chain(:ransack, :result, :includes, :order).and_return(@scope)
      end

      it "does not paginate states results when asked not to do so" do
        @scope.should_not_receive(:page)
        @scope.should_not_receive(:per)
        api_get :index
      end

      it "paginates when page parameter is passed through" do
        @scope.should_receive(:page).with(1).and_return(@scope)
        @scope.should_receive(:per).with(nil)
        api_get :index, :page => 1
      end

      it "paginates when per_page parameter is passed through" do
        @scope.should_receive(:page).with(nil).and_return(@scope)
        @scope.should_receive(:per).with(25)
        api_get :index, :per_page => 25
      end
    end


    context "with two states" do
      before { create(:state, :name => "New South Wales") }

      it "gets all states for a country" do
        country = create(:country, :states_required => true)
        state.country = country 
        state.save

        api_get :index, :country_id => country.id
        json_response["states"].first.should have_attributes(attributes)
        json_response["states"].count.should == 1
        json_response["states_required"] = true
      end

      it "can view all states" do
        api_get :index
        json_response["states"].first.should have_attributes(attributes)
      end

      it 'can query the results through a paramter' do
        api_get :index, :q => { :name_cont => 'Vic' }
        json_response['states'].first['name'].should eq("Victoria")
      end
    end

    it "can view a state" do
      api_get :show, :id => state.id
      json_response.should have_attributes(attributes)
    end
  end
end
