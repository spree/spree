require 'spec_helper'

class PlatformApiDummyController < Spree::Api::V2::Platform::ResourceController
  private

  def model_class
    Spree::Product
  end
end

describe Spree::Api::V2::Platform::ResourceController, type: :controller do
  let(:dummy_controller) { PlatformApiDummyController.new }
  let(:store) { @default_store }

  describe '#resource_serializer' do
    subject { dummy_controller.send(:resource_serializer) }

    it { expect(subject).to be Spree::Api::V2::Platform::ProductSerializer }
  end

  describe '#collection_serializer' do
    it { expect(dummy_controller.send(:collection_serializer)).to be Spree::Api::V2::Platform::ProductSerializer }
  end

  describe '#collection' do
    let!(:product) { create(:product, stores: [store]) }
    let!(:product_from_another_store) { create(:product, stores: [create(:store)]) }
    let(:collection) { dummy_controller.send(:collection) }

    before do
      dummy_controller.params = {}
      allow(dummy_controller).to receive(:current_store).and_return(store)
      allow(dummy_controller).to receive(:spree_current_user).and_return(nil)
    end

    it 'returns collection of records from the current store' do
      expect(collection.first).to be_instance_of(Spree::Product)
      expect(collection.count).to eq(store.products.count)
      expect(collection.map(&:id)).to include(product.id)
      expect(collection.map(&:id)).not_to include(product_from_another_store.id)
    end
  end

  describe '#permitted_resource_params' do
    let(:valid_attributes) do
      {
        product: {
          name: 'Test'
        }
      }
    end

    before do
      dummy_controller.params = valid_attributes
    end

    it { expect(dummy_controller.send(:permitted_resource_params)).to eq(ActionController::Parameters.new(valid_attributes).require(:product).permit!) }

    context 'when model supports metafields' do
      before do
        allow(dummy_controller).to receive(:model_class).and_return(Spree::Product)
      end

      let!(:metafield_definition) { create(:metafield_definition, :short_text_field, resource_type: Spree::Product) }

      let(:valid_attributes) do
        {
          product: {
            name: 'Test',
            metafields_attributes: [{ metafield_definition_id: metafield_definition.id, value: 'Test' }]
          }
        }
      end

      it { expect(dummy_controller.send(:permitted_resource_params)).to include(:metafields_attributes) }
    end
  end
end
