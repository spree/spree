require 'spec_helper'

RSpec.describe Spree::Admin::StatesController, type: :controller do
  stub_authorization!

  render_views

  describe 'GET #select_options' do
    subject { get :select_options, params: { country_id: country_id }, format: :json }

    let(:country_id) { country_a.id }
    let(:json) { JSON.parse(response.body) }
    let(:names) { json.map { |s| s['name'] } }

    let!(:country_a) { create(:country) }
    let!(:country_b) { create(:country) }
    let!(:empty_country) { create(:country) }
    let!(:state_a1) { create(:state, name: 'Alabama', country: country_a) }
    let!(:state_a2) { create(:state, name: 'California', country: country_a) }
    let!(:state_b1) { create(:state, name: 'Ontario', country: country_b) }

    it 'returns states for a given country' do
      subject

      expect(names).to contain_exactly('Alabama', 'California')
    end

    it 'returns states ordered by name' do
      subject

      expect(names).to eq(names.sort)
    end

    context 'when country has no states' do
      let(:country_id) { empty_country.id }

      it 'returns empty array' do
        subject

        expect(json).to be_empty
      end
    end
  end
end
