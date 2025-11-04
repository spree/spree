require 'spec_helper'

class ApiV3DummyController < Spree::Api::V3::ResourceController
  private

  def model_class
    Spree::Product
  end

  def serializer_class
    Spree::Api::V3::ProductSerializer
  end

  def permitted_params
    {}
  end
end

describe Spree::Api::V3::ResourceController, type: :controller do
  let(:dummy_controller) { ApiV3DummyController.new }
  let(:store) { @default_store }
  let!(:products) { create_list(:product, 30, stores: [store]) }

  before do
    request = double('request').as_null_object
    allow(request).to receive(:base_url).and_return('http://example.com')
    allow(request).to receive(:path).and_return('/api/v3/products')
    allow(request).to receive(:query_string).and_return('')
    allow(request).to receive(:GET).and_return({})
    allow(request).to receive(:POST).and_return({})
    allow(request).to receive(:cookies).and_return({})

    allow(dummy_controller).to receive(:current_store).and_return(store)
    allow(dummy_controller).to receive(:current_ability).and_return(Spree::Ability.new(nil))
    allow(dummy_controller).to receive(:params).and_return(ActionController::Parameters.new(params))
    allow(dummy_controller).to receive(:request).and_return(request)
  end

  describe '#collection' do
    context 'with default pagination' do
      let(:params) { {} }

      it 'paginates with default limit of 25' do
        collection = dummy_controller.send(:collection)
        expect(collection.size).to eq(25)
      end

      it 'sets pagy instance variable' do
        dummy_controller.send(:collection)
        pagy = dummy_controller.instance_variable_get(:@pagy)
        expect(pagy).to be_a(Pagy)
        expect(pagy.limit).to eq(25)
        expect(pagy.page).to eq(1)
        expect(pagy.count).to eq(30)
      end
    end

    context 'with custom per_page parameter' do
      let(:params) { { per_page: 10 } }

      it 'paginates with specified limit' do
        collection = dummy_controller.send(:collection)
        expect(collection.size).to eq(10)
      end

      it 'sets correct pagy metadata' do
        dummy_controller.send(:collection)
        pagy = dummy_controller.instance_variable_get(:@pagy)
        expect(pagy.limit).to eq(10)
        expect(pagy.pages).to eq(3)
      end
    end

    context 'with custom limit parameter' do
      let(:params) { { limit: 15 } }

      it 'paginates with specified limit' do
        collection = dummy_controller.send(:collection)
        expect(collection.size).to eq(15)
      end
    end

    context 'with page parameter' do
      let(:params) { { page: 2, per_page: 10 } }

      it 'returns correct page' do
        collection = dummy_controller.send(:collection)
        expect(collection.size).to eq(10)
        pagy = dummy_controller.instance_variable_get(:@pagy)
        expect(pagy.page).to eq(2)
      end
    end

    context 'with limit exceeding maximum' do
      let(:params) { { per_page: 200 } }

      it 'caps at maximum of 100' do
        collection = dummy_controller.send(:collection)
        pagy = dummy_controller.instance_variable_get(:@pagy)
        expect(pagy.limit).to eq(100)
      end
    end
  end

  describe '#collection_meta' do
    let(:params) { { page: 1, per_page: 10 } }

    before do
      dummy_controller.send(:collection)
    end

    it 'returns data_hash with pagination metadata' do
      meta = dummy_controller.send(:collection_meta, nil)
      expect(meta).to be_a(Hash)
      expect(meta[:count]).to eq(30)
      expect(meta[:pages]).to eq(3)
      expect(meta[:page]).to eq(1)
      expect(meta[:limit]).to eq(10)
      expect(meta[:from]).to eq(1)
      expect(meta[:to]).to eq(10)
      expect(meta[:in]).to eq(10)
    end

    context 'on last page' do
      let(:params) { { page: 3, per_page: 10 } }

      it 'returns correct metadata for last page' do
        dummy_controller.send(:collection)
        meta = dummy_controller.send(:collection_meta, nil)
        expect(meta[:count]).to eq(30)
        expect(meta[:pages]).to eq(3)
        expect(meta[:page]).to eq(3)
        expect(meta[:limit]).to eq(10)
        expect(meta[:from]).to eq(21)
        expect(meta[:to]).to eq(30)
        expect(meta[:in]).to eq(10)
      end
    end
  end

  describe '#limit' do
    context 'with per_page parameter' do
      let(:params) { { per_page: 50 } }

      it 'returns the per_page value' do
        expect(dummy_controller.send(:limit)).to eq(50)
      end
    end

    context 'with limit parameter' do
      let(:params) { { limit: 30 } }

      it 'returns the limit value' do
        expect(dummy_controller.send(:limit)).to eq(30)
      end
    end

    context 'with both per_page and limit parameters' do
      let(:params) { { per_page: 20, limit: 30 } }

      it 'prefers per_page over limit' do
        expect(dummy_controller.send(:limit)).to eq(20)
      end
    end

    context 'without parameters' do
      let(:params) { {} }

      it 'returns default limit of 25' do
        expect(dummy_controller.send(:limit)).to eq(25)
      end
    end

    context 'with limit exceeding maximum' do
      let(:params) { { per_page: 150 } }

      it 'caps at 100' do
        expect(dummy_controller.send(:limit)).to eq(100)
      end
    end
  end
end
