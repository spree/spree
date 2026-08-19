require 'spec_helper'

RSpec.describe SpreeStripe::StatementDescriptorSuffixPresenter do
  subject(:presenter) { described_class.new(order_description: order_description).call }

  context 'when order_description contains allowed characters' do
    let(:order_description) { 'Order123' }

    it 'returns the upcased order description' do
      expect(presenter).to eq('ORDER123')
    end
  end

  context 'when order_description contains not allowed characters' do
    let(:order_description) { "Order<1>'*2\\" }

    it 'removes not allowed characters' do
      expect(presenter).to eq('ORDER12')
    end
  end

  context 'when order_description contains lowercase and spaces' do
    let(:order_description) { 'order 123' }

    it 'upcases and trims spaces' do
      expect(presenter).to eq('ORDER 123')
    end
  end

  context 'when order_description is longer than max chars' do
    let(:order_description) { 'ABCDEFGHIJKL' }

    it 'truncates to max chars' do
      expect(presenter.length).to eq(described_class::STATEMENT_DESCRIPTOR_MAX_CHARS)
      expect(presenter).to eq('ABCDEFGHIJ')
    end
  end

  context 'when order_description contains unicode characters' do
    let(:order_description) { 'Café Über' }

    it 'transliterates unicode to ascii' do
      expect(presenter).to eq('CAFE UBER')
    end
  end

  context 'when order_description is blank' do
    let(:order_description) { '' }

    it 'returns nil' do
      expect(presenter).to be_nil
    end
  end

  context 'when order_description has leading and trailing spaces' do
    let(:order_description) { '  order 123  ' }

    it 'strips spaces' do
      expect(presenter).to eq('ORDER 123')
    end
  end

  context 'when order_description does not contain a letter' do
    let(:order_description) { '123' }

    it 'adds the prefix' do
      expect(presenter).to eq('O#123')
    end

    context 'when order_description is longer than max chars' do
      let(:order_description) { '12345678901' }

      it 'truncates to max chars' do
        expect(presenter).to eq('O#12345678')
      end
    end
  end
end
