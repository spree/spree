require 'spec_helper'

class DummyController < Spree::Api::V2::BaseController
  private

  def default_resource_includes
    %w[variants images]
  end
end

describe Spree::Api::V2::BaseController, type: :controller do
  let(:dummy_controller) { DummyController.new }

  describe '#default_resource_includes' do
    context 'not implemented' do
      it 'returns an empty array' do
        expect(controller.send(:default_resource_includes)).to eq([])
      end
    end

    context 'implemented' do
      it 'overrides the method' do
        expect(dummy_controller.send(:default_resource_includes)).to eq(%w[variants images])
      end
    end
  end

  describe '#resource_includes' do
    context 'passed as params' do
      before do
        dummy_controller.params = { include: 'variants,images,taxons' }
      end

      it 'returns included resources specified in params' do
        expect(dummy_controller.send(:resource_includes)).to eq([:variants, :images, :taxons])
      end
    end

    context 'not passed in params' do
      before do
        dummy_controller.params = {}
      end

      it 'returns default resources' do
        expect(dummy_controller.send(:resource_includes)).to eq([:variants, :images])
      end
    end
  end

  describe '#sparse_fields' do
    shared_examples 'invalid params format' do
      it 'returns nil' do
        expect(dummy_controller.send(:sparse_fields)).to eq(nil)
      end
    end

    context 'not passed in params' do
      before do
        dummy_controller.params = {}
      end

      it_behaves_like 'invalid params format'
    end

    context 'with no field type specified' do
      before do
        dummy_controller.params = { fields: 'name,slug,price' }
      end

      it_behaves_like 'invalid params format'
    end

    context 'with type values not comma separated' do
      before do
        dummy_controller.params = { fields: { product: { values: 'name,slug,price' } } }
      end

      it_behaves_like 'invalid params format'
    end

    context 'with valid params format' do
      before do
        dummy_controller.params = { fields: { product: 'name,slug,price' } }
      end

      it 'returns specified params' do
        expect(dummy_controller.send(:sparse_fields)).to eq(product: [:name, :slug, :price])
      end
    end
  end
end
