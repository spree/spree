require 'spec_helper'

describe Spree::Core::ControllerHelpers::Store, type: :controller do

  controller do
    include Spree::Core::ControllerHelpers::Store
  end

  describe '#current_store' do
    let!(:store) { create :store, default: true }
    it 'returns current store' do
      expect(controller.current_store).to eq store
    end
  end
end
