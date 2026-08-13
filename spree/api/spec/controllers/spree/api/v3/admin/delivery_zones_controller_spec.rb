require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryZonesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:country) { Spree::Country.by_iso('US') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:zone) { create(:delivery_zone, name: 'Domestic') }

    it 'lists delivery zones' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |z| z['name'] }).to include('Domestic')
    end
  end

  describe 'POST #create' do
    it 'creates a zone with typed members' do
      post :create, params: {
        name: 'US North-East',
        expand: 'members',
        members: [
          { member_type: 'country', country_iso: 'US' },
          { member_type: 'postal_code', country_iso: 'US', postal_code_prefix: '10' }
        ]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('US North-East')
      expect(json_response['members'].length).to eq(2)
      expect(json_response['members'].map { |m| m['member_type'] }).to contain_exactly('country', 'postal_code')
      expect(json_response['members'].find { |m| m['member_type'] == 'postal_code' }['postal_code_prefix']).to eq('10')
    end

    it 'validates member shapes' do
      post :create, params: {
        name: 'Broken',
        members: [{ member_type: 'postal_code' }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:zone) do
      create(:delivery_zone, name: 'Domestic').tap do |z|
        z.members.create!(member_type: 'country', country: country)
      end
    end

    it 'replaces the member set atomically' do
      patch :update, params: {
        id: zone.prefixed_id,
        name: 'Domestic v2',
        members: [{ member_type: 'postal_code', country_iso: 'US', postal_code_from: '10000', postal_code_to: '19999' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(zone.reload.name).to eq('Domestic v2')
      expect(zone.members.count).to eq(1)
      expect(zone.members.first.member_type).to eq('postal_code')
    end

    it 'keeps members untouched when the payload has none' do
      patch :update, params: { id: zone.prefixed_id, name: 'Renamed' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(zone.reload.members.count).to eq(1)
    end
  end

  describe 'DELETE #destroy' do
    let!(:zone) { create(:delivery_zone) }

    it 'deletes the zone' do
      delete :destroy, params: { id: zone.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryZone.exists?(zone.id)).to be(false)
    end

    # The confirm dialog promises the methods go with the zone — hold the API
    # to it, since a nullify regression would silently widen them to worldwide.
    it 'deletes the zone methods with it' do
      method = create(:delivery_method, store: store, delivery_zone: zone,
                                        delivery_profile: zone.delivery_profile,
                                        delivery_origin_group: zone.delivery_origin_group)

      delete :destroy, params: { id: zone.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryMethod.exists?(method.id)).to be(false)
      expect(Spree::DeliveryMethod.with_deleted.find(method.id).delivery_zone_id).to eq(zone.id)
    end
  end

  # The edit form replaces the full member set on save, so a GET that omits
  # members would make the very next save wipe them (dashboard bug, 2026-08-09:
  # the edit sheet fetched without expand and Save emptied the zone).
  describe 'member round-trip' do
    it 'returns members on show when expanded, and preserves them when echoed back' do
      zone = create(:delivery_zone, store: store)
      us = Spree::Country.by_iso('US')
      de = Spree::Country.by_iso('DE')
      zone.members.create!(member_type: 'country', country: us)
      zone.members.create!(member_type: 'country', country: de)

      get :show, params: { id: zone.prefixed_id, expand: 'members' }, as: :json

      expect(response).to have_http_status(:ok)
      members = json_response['members']
      expect(members.map { |member| member['country_iso'] }).to match_array(%w[US DE])

      patch :update, params: {
        id: zone.prefixed_id,
        members: members.map { |member| { member_type: member['member_type'], country_iso: member['country_iso'] } }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(zone.reload.members.count).to eq(2)
    end
  end

end
