require 'spec_helper'
require 'spree/testing_support/url_helpers'

class FakesController < ApplicationController
  include ActionController::Cookies
  include Spree::Core::ControllerHelpers::Auth
  def index
    render plain: 'index'
  end
end

describe Spree::Core::ControllerHelpers::Auth, type: :controller do
  controller(FakesController) {}
  include Spree::TestingSupport::UrlHelpers

  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe '#current_ability' do
    it 'returns Spree::Ability instance' do
      expect(controller.current_ability.class).to eq Spree::Ability
    end
  end

  describe '#store_location' do
    it 'sets session return url' do
      allow(controller).to receive_messages(request: double(fullpath: '/redirect'))
      controller.store_location
      expect(session[:legacy_user_return_to]).to eq '/redirect'
    end
  end

  describe '#try_spree_current_user' do
    it 'calls spree_current_user when defined' do
      expect(controller).to receive(:spree_current_user)
      controller.try_spree_current_user
    end

    it 'returns nil when no user is set' do
      expect(controller.try_spree_current_user).to eq nil
    end

    context 'when spree_current_user is not defined' do
      before do
        allow(controller).to receive(:respond_to?).and_call_original
        allow(controller).to receive(:respond_to?).with(:spree_current_user).and_return(false)
      end

      it 'calls current_spree_user as fallback' do
        allow(controller).to receive(:respond_to?).with(:current_spree_user).and_return(true)
        expect(controller).to receive(:current_spree_user)
        controller.try_spree_current_user
      end

      it 'returns nil when neither method is defined' do
        allow(controller).to receive(:respond_to?).with(:current_spree_user).and_return(false)
        expect(controller.try_spree_current_user).to eq nil
      end
    end
  end
end
