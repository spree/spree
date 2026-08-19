require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Store
end

describe Spree::Core::ControllerHelpers::Store, type: :controller do
  controller(FakesController) {}

  describe '#current_store' do
    let!(:store) { @default_store }
    let!(:store_2) { create :store, url: 'another.com' }

    context 'default store' do
      it 'returns current store' do
        expect(controller.current_store).to eq store
      end
    end
  end

  describe '#ensure_current_store' do
    let!(:store) { @default_store }
    let!(:store_2) { create :store }

    context 'on a single-store object (payment method)' do
      before { allow(controller).to receive(:current_store).and_return(store) }

      context 'when the object has no store associated' do
        let(:object) { build(:payment_method, store: nil) }

        it 'associates the object with the current_store' do
          controller.ensure_current_store(object)
          expect(object.store).to eq(store)
          expect(object.store).not_to eq(store_2)
        end
      end

      context 'when the object has a different store pre assigned' do
        let(:object) { create(:payment_method, store: store_2) }

        it 'raises an exception' do
          expect { controller.ensure_current_store(object) }.to raise_error('Store is already set')
        end
      end

      context 'when the object already has the current store assigned' do
        let(:object) { create(:payment_method, store: store) }

        it 'object is not changed' do
          controller.ensure_current_store(object)
          expect(object.store).to eq(store)
        end
      end
    end

    context 'on an object that accepts a single store' do
      before { allow(controller).to receive(:current_store).and_return(store) }

      context 'when no store is present' do
        object = Spree::Collection.new

        it 'sets the current_store' do
          controller.ensure_current_store(object)
          expect(object.store).to eql(store)
          expect(object.store).not_to eql(store_2)
        end
      end

      context 'when an object already has a store assigned' do
        object = Spree::Collection.new

        it 'raises an exception' do
          object.store = store_2
          object.save

          expect { controller.ensure_current_store(object) }.to raise_error('Store is already set')
        end
      end

      context 'when an object already has a store assigned and the same store is re-assigned' do
        object = Spree::Collection.new

        it 'no exception is raised' do
          object.store = store
          object.save

          expect { controller.ensure_current_store(object) }.not_to raise_error
        end
      end
    end

    context 'when object is nil' do
      before { allow(controller).to receive(:current_store).and_return(store) }

      object = nil

      it 'returns nil' do
        expect(controller.ensure_current_store(object)).to be_nil
      end
    end
  end

  describe '#current_price_options' do
    subject(:current_price_options) { controller.current_price_options }

    after { Spree::Current.reset }

    context 'without a current order' do
      let(:browsing_country) { create(:country) }

      it 'falls back to the browsing context' do
        Spree::Current.tax_country = browsing_country

        expect(subject).to include(country: browsing_country)
      end

      # The resolved country is written back so everything later in the request
      # prices against the same one.
      it 'resolves and publishes the store country when nothing is set yet' do
        expect(subject[:country]).to eq(Spree::Store.default.default_country)
        expect(Spree::Current.attributes[:tax_country]).to eq(subject[:country])
      end

      it 'reports no country when there is none to resolve' do
        allow(Spree::Current).to receive(:tax_country).and_return(nil)

        expect(subject).to include(country: nil)
      end
    end

    context 'with a current order' do
      let(:order_country) { create(:country) }
      let(:current_order) { Spree::Order.new }

      before do
        allow(current_order).to receive(:tax_country).and_return(order_country)
        allow(controller).to receive(:current_order).and_return(current_order)
        controller.instance_variable_set(:@current_order, current_order)
      end

      it { is_expected.to include(country: order_country) }

      it 'publishes the order country to the request context' do
        subject
        expect(Spree::Current.tax_country).to eq(order_country)
      end
    end
  end

  describe '#raise_record_not_found_if_store_is_not_found' do
    let(:store) { create :store }

    context 'when the store is not found' do
      before do
        allow(controller).to receive(:current_store).and_return(nil)
      end

      it 'raises an exception' do
        expect { controller.send(:raise_record_not_found_if_store_is_not_found) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with root_domain set' do
      before do
        allow(Spree).to receive(:root_domain).and_return('example.com')
        controller.request.env['SERVER_NAME'] = 'example.com'
      end

      it 'does not raise an exception' do
        expect { controller.send(:raise_record_not_found_if_store_is_not_found) }.not_to raise_error
      end
    end

    context 'when store is found' do
      before do
        allow(controller).to receive(:current_store).and_return(store)
      end

      it 'does not raise an exception' do
        expect { controller.send(:raise_record_not_found_if_store_is_not_found) }.not_to raise_error
      end
    end
  end
end
