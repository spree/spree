require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Currency
end

describe Spree::Core::ControllerHelpers::Currency, type: :controller do
  controller(FakesController) {}

  describe '#current_currency' do
    let!(:store) { create :store, default: true, default_currency: 'GBP' }

    it 'returns current store default currency' do
      expect(controller.current_currency).to eq('GBP')
    end
  end

  describe '#supported_currencies' do
    let(:currency) { 'EUR' }
    let!(:store) { create :store, default: true, supported_currencies: currency }

    it 'returns supported currencies' do
      expect(controller.supported_currencies).to include(::Money::Currency.find(currency))
    end
  end

  describe '#currency_param' do
    let!(:store) { create :store, default: true, default_currency: 'EUR', supported_currencies: 'EUR,GBP' }

    context 'same as store default locale' do
      before { controller.params = { currency: 'EUR' } }

      it { expect(controller.currency_param).to eq(nil) }
    end

    context 'different than store locale' do
      before { controller.params = { currency: 'GBP' } }

      it { expect(controller.currency_param).to eq('GBP') }
    end
  end
end
