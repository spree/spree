require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductFiltersSerializer do
  let(:store) { @default_store }
  let(:result) do
    Spree::SearchProvider::FiltersResult.new(
      filters: [
        { id: 'price', type: 'price_range', min: 10.0, max: 100.0, currency: 'USD' },
        {
          id: 'availability',
          type: 'availability',
          options: [
            { id: 'in_stock', count: 2 },
            { id: 'out_of_stock', count: 0 }
          ]
        },
        {
          id: 'opt_abc123',
          type: 'option',
          name: 'size',
          label: 'Size',
          kind: 'dropdown',
          options: [
            {
              id: 'optval_abc123',
              name: 'small',
              label: 'S',
              position: 1,
              color_code: nil,
              image_url: nil,
              count: 1
            }
          ]
        },
        {
          id: 'categories',
          type: 'category',
          options: [
            {
              id: 'ctg_abc123',
              name: 'Shirts',
              permalink: 'clothing/shirts',
              count: 2
            }
          ]
        }
      ],
      sort_options: [{ id: 'price' }, { id: '-price' }],
      default_sort: 'manual',
      total_count: 5
    )
  end
  let(:base_params) { { store: store, currency: 'USD', locale: 'en' } }

  describe 'store serializer' do
    subject { described_class.new(result, params: base_params).to_h }

    it 'serializes filter metadata' do
      expect(subject).to eq(
        'filters' => [
          { 'id' => 'price', 'type' => 'price_range', 'min' => 10.0, 'max' => 100.0, 'currency' => 'USD' },
          {
            'id' => 'availability',
            'type' => 'availability',
            'options' => [
              { 'id' => 'in_stock', 'count' => 2 },
              { 'id' => 'out_of_stock', 'count' => 0 }
            ]
          },
          {
            'id' => 'opt_abc123',
            'type' => 'option',
            'name' => 'size',
            'label' => 'Size',
            'kind' => 'dropdown',
            'options' => [
              {
                'id' => 'optval_abc123',
                'name' => 'small',
                'label' => 'S',
                'position' => 1,
                'color_code' => nil,
                'image_url' => nil,
                'count' => 1
              }
            ]
          },
          {
            'id' => 'categories',
            'type' => 'category',
            'options' => [
              {
                'id' => 'ctg_abc123',
                'name' => 'Shirts',
                'permalink' => 'clothing/shirts',
                'count' => 2
              }
            ]
          }
        ],
        'id' => nil,
        'sort_options' => [{ 'id' => 'price' }, { 'id' => '-price' }],
        'default_sort' => 'manual',
        'total_count' => 5
      )
    end

    it 'raises for unknown filter types' do
      invalid_result = Spree::SearchProvider::FiltersResult.new(
        filters: [{ type: 'unknown' }],
        sort_options: [],
        default_sort: 'manual',
        total_count: 0
      )

      expect {
        described_class.new(invalid_result, params: base_params).to_h
      }.to raise_error(ArgumentError, 'Unknown filter type: "unknown"')
    end
  end
end
