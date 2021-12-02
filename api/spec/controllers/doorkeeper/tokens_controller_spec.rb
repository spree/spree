require 'spec_helper'

describe Doorkeeper::TokensController, type: :controller do
  describe '#current_store' do
    let!(:store) { create :store, default: true }

    it 'returns current store' do
      expect(controller.current_store).to eq(store)
    end
  end
end
