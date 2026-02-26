require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Currency
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
    let!(:store) { create :store, default: true }
    let!(:store_2) { create :store }

    context 'on an object that accepts multiple stores' do
      before { allow(controller).to receive(:current_store).and_return(store) }

      context 'when the object has no stores associated' do
        let(:object) { build(:product, stores: []) }

        it 'associates the object with the current_store' do
          controller.ensure_current_store(object)
          expect(object.stores).to contain_exactly(store)
          expect(object.stores).not_to contain_exactly(store_2)
        end
      end

      context 'when the object has a store pre assigned' do
        let(:object) { create(:product, stores: [store_2]) }

        it 'adds the new store without removing the original store' do
          controller.ensure_current_store(object)
          expect(object.stores).to contain_exactly(store, store_2)
        end
      end

      context 'when the object has a store and the same store is attempted to be added' do
        let(:object) { create(:product, stores: [store]) }

        it 'object is not changed' do
          controller.ensure_current_store(object)
          expect(object.stores).to contain_exactly(store)
        end
      end
    end

    context 'on a object that accepts a single store' do
      before { allow(controller).to receive(:current_store).and_return(store) }

      context 'when no store is present' do
        object = Spree::Taxonomy.new

        it 'sets the current_store' do
          controller.ensure_current_store(object)
          expect(object.store).to eql(store)
          expect(object.store).not_to eql(store_2)
        end
      end

      context 'when an object already has a store assigned' do
        object = Spree::Taxonomy.new

        it 'raises an exception' do
          object.store = store_2
          object.save

          expect { controller.ensure_current_store(object) }.to raise_error('Store is already set')
        end
      end

      context 'when an object already has a store assigned and the same store is re-assigned' do
        object = Spree::Taxonomy.new

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

    context 'when there is a default tax zone' do
      let(:default_zone) { Spree::Zone.new }

      before do
        allow(Spree::Zone).to receive(:default_tax).and_return(default_zone)
      end

      context 'when there is no current order' do
        it 'returns the default tax zone' do
          expect(subject).to include(tax_zone: default_zone)
        end

        it 'sets Spree::Current.zone to the default tax zone' do
          subject
          expect(Spree::Current.zone).to eq(default_zone)
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

        it 'sets Spree::Current.zone to the order tax zone' do
          subject
          expect(Spree::Current.zone).to eq(other_zone)
        end
      end
    end

    context 'when there is no default tax zone' do
      before do
        allow(Spree::Zone).to receive(:default_tax).and_return(nil)
      end

      context 'when there is no current order' do
        it 'returns nil when asked for the current tax zone' do
          expect(current_price_options[:tax_zone]).to be_nil
        end

        it 'sets Spree::Current.zone to nil' do
          subject
          # Spree::Current.zone will call default_tax again, so we check the attributes hash
          expect(Spree::Current.attributes[:zone]).to be_nil
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

        it 'sets Spree::Current.zone to the order tax zone' do
          subject
          expect(Spree::Current.zone).to eq(other_zone)
        end
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
