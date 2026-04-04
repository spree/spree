require 'spec_helper'

RSpec.describe Spree::CSV::ProductTranslationPresenter do
  let(:store) { @default_store }
  let!(:product) { create(:product) }
  let(:presenter) { described_class.new(product, 'de') }

  before do
    Mobility.with_locale(:de) do
      product.update!(
        name: 'Jeanshemd',
        description: 'Ein klassisches Jeanshemd.',
        meta_title: 'Jeanshemd | Demo',
        meta_description: 'Klassisches Jeanshemd.'
      )
    end
  end

  describe '#call' do
    subject { presenter.call }

    it 'returns the correct CSV row' do
      expect(subject).to eq [
        product.slug,
        'de',
        'Jeanshemd',
        'Ein klassisches Jeanshemd.',
        'Jeanshemd | Demo',
        'Klassisches Jeanshemd.'
      ]
    end

    it 'has the same number of columns as CSV_HEADERS' do
      expect(subject.size).to eq described_class::CSV_HEADERS.size
    end
  end

  describe 'when translation is partial' do
    before do
      Mobility.with_locale(:fr) { product.update!(name: 'Produit Test') }
    end

    let(:presenter) { described_class.new(product, 'fr') }

    it 'returns nil for untranslated fields' do
      result = presenter.call
      expect(result[0]).to eq product.slug
      expect(result[1]).to eq 'fr'
      expect(result[2]).to eq 'Produit Test'
      expect(result[3]).to be_nil # description
      expect(result[4]).to be_nil # meta_title
      expect(result[5]).to be_nil # meta_description
    end
  end
end
