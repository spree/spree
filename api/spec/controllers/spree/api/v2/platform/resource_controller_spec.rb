require 'spec_helper'

class PlatformApiDummyController < Spree::Api::V2::Platform::ResourceController
  private

  def model_class
    Spree::Product
  end
end

describe Spree::Api::V2::Platform::ResourceController, type: :controller do
  let(:dummy_controller) { PlatformApiDummyController.new }
  let(:store) { Spree::Store.default }

  describe '#resource_serializer' do
    subject { dummy_controller.send(:resource_serializer) }

    context 'when controller model class is nested more than 2 levels' do
      before do
        allow(dummy_controller).to receive(:model_class).and_return(Spree::Webhooks::Subscriber)
      end

      it { expect(subject).to eq(Spree::Api::V2::Platform::Webhooks::SubscriberSerializer) }
    end

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

    it { expect(collection.first).to be_instance_of(Spree::Product) }
    it { expect(collection.count).to eq(store.products.count) }
    it { expect(collection.map(&:id)).to include(product.id) }
    it { expect(collection.map(&:id)).not_to include(product_from_another_store.id) }
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
  end
end
