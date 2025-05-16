require 'spec_helper'

RSpec.describe Spree::Admin::ZonesController do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:zone) { create(:zone) }

    it 'renders the index template' do
      get :index
      expect(response).to be_successful
      expect(response).to render_template(:index)
      expect(assigns(:zones)).to include(zone)
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new
      expect(response).to be_successful
      expect(response).to render_template(:new)
      expect(assigns(:zone)).to be_a_new(Spree::Zone)
    end
  end

  describe 'POST #create' do
    context 'with country based zone' do
      let(:country) { create(:country) }
      let(:zone_params) do
        {
          name: 'EU Zone',
          description: 'Countries in EU',
          kind: 'country',
          default_tax: true,
          country_ids: [country.id]
        }
      end

      it 'creates a new country-based zone' do
        expect { post :create, params: { zone: zone_params } }.to change(Spree::Zone, :count).by(1)

        zone = Spree::Zone.last
        expect(zone).to be_persisted
        expect(zone.name).to eq('EU Zone')
        expect(zone.kind).to eq('country')
        expect(zone.default_tax).to be true
        expect(zone.zone_members.count).to eq(1)
        expect(zone.zone_members.first.zoneable).to be_a(Spree::Country)
        expect(zone.zone_members.first.zoneable.id).to eq(country.id)
      end
    end

    context 'with state based zone' do
      let!(:country) { create(:country) }
      let!(:state) { create(:state, country: country) }
      let(:zone_params) do
        {
          name: 'California Zone',
          description: 'California tax zone',
          kind: 'state',
          default_tax: true,
          state_country_id: country.id,
          state_ids: [state.id]
        }
      end

      it 'creates a new state-based zone' do
        expect { post :create, params: { zone: zone_params } }.to change(Spree::Zone, :count).by(1)

        zone = Spree::Zone.last
        expect(zone).to be_persisted
        expect(zone.name).to eq('California Zone')
        expect(zone.kind).to eq('state')
        expect(zone.default_tax).to be true
        expect(zone.zone_members.count).to eq(1)
        expect(zone.zone_members.first.zoneable).to be_a(Spree::State)
        expect(zone.zone_members.first.zoneable.id).to eq(state.id)
      end
    end
  end

  describe 'GET #edit' do
    let!(:zone) { create(:zone) }

    it 'renders the edit template' do
      get :edit, params: { id: zone.id }
      expect(response).to be_successful
      expect(response).to render_template(:edit)
      expect(assigns(:zone)).to eq(zone)
    end
  end

  describe 'PUT #update' do
    let!(:zone) { create(:zone, name: 'Old Name') }

    it 'updates the zone' do
      put :update, params: { id: zone.id, zone: { name: 'New Name' } }

      expect(zone.reload.name).to eq('New Name')
    end
  end

  describe 'DELETE #destroy' do
    let!(:zone) { create(:zone) }

    it 'deletes the zone' do
      expect { delete :destroy, params: { id: zone.id } }.to change(Spree::Zone, :count).by(-1)

      expect(response).to redirect_to(spree.admin_zones_path)
      expect(Spree::Zone.find_by(id: zone.id)).to be_nil
    end
  end
end
