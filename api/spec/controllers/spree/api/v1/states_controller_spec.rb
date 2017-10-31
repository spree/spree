require 'spec_helper'

module Spree
  describe Api::V1::StatesController, type: :controller do
    render_views

    let!(:state) { create(:state, name: 'Victoria') }
    let(:attributes) { [:id, :name, :abbr, :country_id] }

    before do
      stub_authentication!
    end

    it 'gets all states' do
      api_get :index
      expect(json_response['states'].first).to have_attributes(attributes)
      expect(json_response['states'].first['name']).to eq(state.name)
    end

    it 'gets all the states for a particular country' do
      api_get :index, country_id: state.country.id
      expect(json_response['states'].first).to have_attributes(attributes)
      expect(json_response['states'].first['name']).to eq(state.name)
    end

    context 'pagination' do
      let(:scope) { double('scope') }

      before do
        expect(scope).to receive_messages(last: state)
        expect(State).to receive_messages(accessible_by: scope)
        expect(scope).to receive_messages(order: scope)
        allow(scope).to receive_message_chain(:ransack, :result, :includes).and_return(scope)
      end

      it 'does not paginate states results when asked not to do so' do
        expect(scope).not_to receive(:page)
        expect(scope).not_to receive(:per)
        api_get :index
      end

      it 'paginates when page parameter is passed through' do
        expect(scope).to receive(:page).with('1').and_return(scope)
        expect(scope).to receive(:per).with(nil).and_return(scope)
        api_get :index, page: 1
      end

      it 'paginates when per_page parameter is passed through' do
        expect(scope).to receive(:page).with(nil).and_return(scope)
        expect(scope).to receive(:per).with('25').and_return(scope)
        api_get :index, per_page: 25
      end
    end

    context 'with two states' do
      before { create(:state, name: 'New South Wales') }

      it 'gets all states for a country' do
        country = create(:country, states_required: true)
        state.country = country
        state.save

        api_get :index, country_id: country.id
        expect(json_response['states'].first).to have_attributes(attributes)
        expect(json_response['states'].count).to eq(1)
        json_response['states_required'] = true
      end

      it 'can view all states' do
        api_get :index
        expect(json_response['states'].first).to have_attributes(attributes)
      end

      it 'can query the results through a paramter' do
        api_get :index, q: { name_cont: 'Vic' }
        expect(json_response['states'].first['name']).to eq('Victoria')
      end
    end

    it 'can view a state' do
      api_get :show, id: state.id
      expect(json_response).to have_attributes(attributes)
    end
  end
end
