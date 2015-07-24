require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Search
end

describe Spree::Core::ControllerHelpers::Search, type: :controller do
  controller(FakesController) {}

  describe '#build_searcher' do
    it 'returns Spree::Core::Search::Product instance' do
      allow(controller).to receive_messages(try_spree_current_user: create(:user),
                                            current_currency: 'USD')
      expect(controller.build_searcher(:Product, {}).class).to eq Spree::Core::Search::Product
    end

    it 'returns Spree::Core::Search::Variant instance' do
      allow(controller).to receive_messages(try_spree_current_user: create(:user),
                                            current_currency: 'USD')
      expect(controller.build_searcher(:Variant, {}).class).to eq Spree::Core::Search::Variant
    end
  end
end
