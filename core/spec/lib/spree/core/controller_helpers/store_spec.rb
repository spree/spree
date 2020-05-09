require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Store

  before_action :set_current_order
end

describe Spree::Core::ControllerHelpers::Store, type: :controller do
  controller(FakesController) {}

  describe '#current_store' do
    let!(:store) { create :store, default: true }

    it 'returns current store' do
      expect(controller.current_store).to eq store
    end
  end

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

  describe '#current_price_options' do
    subject(:current_price_options) { controller.current_price_options }

    context 'when there is a default tax zone' do
      let(:default_zone) { Spree::Zone.new }

      before do
        allow(Spree::Zone).to receive(:default_tax).and_return(default_zone)
      end

      context 'when there is no current order' do
        it 'returns the default tax zone' do
          expect(subject).to include(tax_zone: default_zone)
        end
      end

      context 'when there is a current order' do
        let(:other_zone) { Spree::Zone.new }
        let(:current_order) { Spree::Order.new }

        before do
          allow(current_order).to receive(:tax_zone).and_return(other_zone)
          allow(controller).to receive(:current_order).and_return(current_order)
          controller.instance_variable_set(:@current_order, current_order)
        end

        it { is_expected.to include(tax_zone: other_zone) }
      end
    end

    context 'when there is no default tax zone' do
      before do
        allow(Spree::Zone).to receive(:default_tax).and_return(nil)
      end

      context 'when there is no current order' do
        it 'return nil when asked for the current tax zone' do
          expect(current_price_options[:tax_zone]).to be_nil
        end
      end

      context 'when there is a current order' do
        let(:other_zone) { Spree::Zone.new }
        let(:current_order) { Spree::Order.new }

        before do
          allow(current_order).to receive(:tax_zone).and_return(other_zone)
          allow(controller).to receive(:current_order).and_return(current_order)
          controller.instance_variable_set(:@current_order, current_order)
        end

        it { is_expected.to include(tax_zone: other_zone) }
      end
    end
  end
end
