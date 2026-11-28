require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CustomFieldDefinitionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  let!(:delivery_date) do
    create(:custom_field_definition, :for_order, :date_field, store: store, namespace: 'checkout', label: 'Delivery date',
                                                              storefront_writable: true, validations: { required: true, min: '2026-01-01' })
  end
  let!(:gender) do
    create(:custom_field_definition, :for_user, :choice_field, store: store, namespace: 'profile', key: 'gender', storefront_writable: true)
  end

  describe 'GET #index' do
    subject { get :index }

    it_behaves_like 'a list without N+1 queries'

    it 'lists the fields shoppers fill in, with their rules' do
      subject

      expect(json_response['data'].pluck('full_key')).to contain_exactly('checkout.delivery_date', 'profile.gender')

      field = json_response['data'].find { |definition| definition['full_key'] == 'checkout.delivery_date' }
      expect(field).to include('id' => delivery_date.prefixed_id, 'namespace' => 'checkout', 'key' => 'delivery_date',
                               'label' => 'Delivery date', 'field_type' => 'date', 'resource_type' => 'order')
      expect(field['validations']).to include('required' => true, 'min' => '2026-01-01')
      expect(field).not_to include('storefront_visible', 'searchable', 'filter_key')
    end

    it 'filters by resource' do
      get :index, params: { q: { resource_type_eq: 'customer' } }

      field = json_response['data'].sole
      expect(field['full_key']).to eq('profile.gender')
      expect(field['validations']['choices'].first).to eq('value' => 'a', 'label' => 'Zone A')
    end

    it "never lists a field shoppers only read, an admin-only one, or another store's" do
      create(:custom_field_definition, :for_order, store: store, key: 'read_only')
      create(:custom_field_definition, :for_order, :admin_only, store: store, key: 'internal')
      create(:custom_field_definition, :for_order, store: create(:store), key: 'foreign', storefront_writable: true)

      subject

      expect(json_response['data'].pluck('key')).to contain_exactly('delivery_date', 'gender')
    end

    it 'refuses filters that could reach other definitions' do
      get :index, params: { q: { storefront_writable_eq: false } }

      expect(json_response['data'].pluck('key')).to contain_exactly('delivery_date', 'gender')
    end
  end
end
