require 'spec_helper'

class ApiV2DummyController < Spree::Api::V2::ResourceController
  private

  def model_class
    Spree::Product
  end
end

describe Spree::Api::V2::ResourceController, type: :controller do
  let(:dummy_controller) { ApiV2DummyController.new }
  let(:store) { Spree::Store.default }

  describe '#finder_params' do
    let(:currency) { store.default_currency }
    let(:locale) { store.default_locale }
    let(:user) { nil }
    let(:params) { {} }

    shared_examples 'returns proper values' do
      before do
        allow(dummy_controller).to receive(:current_store).and_return(store)
        allow(dummy_controller).to receive(:current_currency).and_return(currency)
        allow(dummy_controller).to receive(:current_locale).and_return(locale)
        allow(dummy_controller).to receive(:spree_current_user).and_return(user)
        allow(dummy_controller).to receive(:params).and_return(params)
      end

      it do
        expect(dummy_controller.send(:finder_params)).to eq(
          params.merge(
            store: store,
            currency: currency,
            user: user,
            locale: locale
          )
        )
      end
    end

    context 'default values' do
      it_behaves_like 'returns proper values'
    end

    context 'non-default values' do
      let(:user) { create(:user) }
      let(:currency) { 'EUR' }
      let(:locale) { 'de' }
      let(:store) { create(:store, default_locale: locale, default_currency: currency) }
      let(:params) { { filter: {}, page: 1, per_page: 10 } }

      it_behaves_like 'returns proper values'
    end
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
end
