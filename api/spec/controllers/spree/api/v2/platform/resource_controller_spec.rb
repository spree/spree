require 'spec_helper'

class PlatformApiDummyController < Spree::Api::V2::Platform::ResourceController
  private

  def model_class
    Spree::Address
  end

  def scope
    Spree::Address
  end
end

describe Spree::Api::V2::Platform::ResourceController, type: :controller do
  let(:dummy_controller) { PlatformApiDummyController.new }

  describe '#resource_serializer' do
    it { expect(dummy_controller.send(:resource_serializer)).to be Spree::Api::V2::Platform::AddressSerializer }
  end

  describe '#collection_serializer' do
    it { expect(dummy_controller.send(:collection_serializer)).to be Spree::Api::V2::Platform::AddressSerializer }
  end

  describe '#collection' do
    before do
      create(:address)
      dummy_controller.params = {}
    end

    let(:collection) { dummy_controller.send(:collection) }

    it { expect(collection).to be_instance_of(Spree::Address.const_get(:ActiveRecord_Relation)) }
    it { expect(collection.first).to be_instance_of(Spree::Address) }
    it { expect(collection.count).to eq(1) }
  end

  describe '#permitted_resource_params' do
    let(:valid_attributes) do
      {
        address: {
          firstname: 'John',
          lastname: 'Snow'
        }
      }
    end

    before do
      dummy_controller.params = valid_attributes
    end

    it { expect(dummy_controller.send(:permitted_resource_params)).to eq(ActionController::Parameters.new(valid_attributes).require(:address).permit!) }
  end
end
