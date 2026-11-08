require 'spec_helper'

RSpec.describe Spree::Api::V3::CustomFieldSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product') }
  let(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'test value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(custom_field, params: base_params).to_h }

    it 'includes key as full_key' do
      expect(subject['key']).to eq(custom_field.full_key)
      expect(subject['key']).to include('.')
    end

    it 'includes label' do
      expect(subject['label']).to eq(custom_field.label)
    end

    it 'names the field type by its token, never the Ruby class' do
      expect(subject['field_type']).to eq('short_text')
      expect(subject).not_to have_key('type')
    end

    it 'includes serialized value' do
      expect(subject['value']).to eq('test value')
    end

    it 'does not include display_on' do
      expect(subject).not_to have_key('display_on')
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::CustomFieldSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product', storefront_visible: false) }
  let(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'admin value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(custom_field, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'key' => custom_field.full_key,
        'label' => custom_field.label,
        'field_type' => custom_field.field_type,
        'value' => 'admin value'
      )
    end

    it 'includes storefront_visible as false for admin-only definitions' do
      expect(subject['storefront_visible']).to be false
    end

    it 'includes storefront_visible as true for storefront-visible definitions' do
      public_definition = create(:custom_field_definition, resource_type: 'Spree::Product')
      public_custom_field = create(:custom_field, resource: product, custom_field_definition: public_definition, value: 'public value')
      result = described_class.new(public_custom_field, params: base_params).to_h
      expect(result['storefront_visible']).to be true
    end

    it 'does not include display_on' do
      expect(subject).not_to have_key('display_on')
    end
  end

  # Every Store API record that can carry custom fields offers them on
  # `expand=custom_fields`: storefront visible values on the Store API, every
  # value on the Admin API.
  describe 'custom_fields expand' do
    let(:address) { create(:address) }
    let(:public_definition) { create(:custom_field_definition, resource_type: 'Spree::Address') }
    let(:private_definition) { create(:custom_field_definition, :admin_only, resource_type: 'Spree::Address') }
    let(:expand_params) { base_params.merge(expand: ['custom_fields']) }

    before do
      create(:custom_field, resource: address, custom_field_definition: public_definition, value: 'public')
      create(:custom_field, resource: address, custom_field_definition: private_definition, value: 'private')
    end

    it 'is omitted unless asked for' do
      expect(Spree::Api::V3::AddressSerializer.new(address, params: base_params).to_h).not_to have_key('custom_fields')
    end

    it 'sends only storefront visible values on the Store API' do
      result = Spree::Api::V3::AddressSerializer.new(address, params: expand_params).to_h

      expect(result['custom_fields'].pluck('value')).to eq(['public'])
    end

    it 'sends every value on the Admin API' do
      result = Spree::Api::V3::Admin::AddressSerializer.new(address, params: expand_params).to_h

      expect(result['custom_fields'].pluck('value')).to contain_exactly('public', 'private')
    end

    it 'is offered by every Store API serializer of a record that can carry custom fields' do
      serializers = %w[
        Address Category Claim Collection Company CreditCard Customer DeliveryMethod Fulfillment GiftCard
        LineItem Media NewsletterSubscriber OptionType OptionValue Order Payment PaymentMethod PaymentSource
        Product Return Seller StoreCredit Variant
      ]

      serializers.each do |name|
        expect(Spree::Api::V3.const_get("#{name}Serializer")._attributes).to have_key(:custom_fields), name
        expect(Spree::Api::V3::Admin.const_get("#{name}Serializer")._attributes).to have_key(:custom_fields), name
      end
    end
  end
end
