require 'spec_helper'

describe Spree::OrderPopulator, :type => :model do
  subject { Spree::OrderPopulator.new(order, 'USD') }

  let(:order) { double('Order', line_items: line_items, contents: contents) }
  let(:line_items) { [] }
  let(:line_item) { double('Line Item').as_null_object }
  let(:contents) { double('Contents', add: line_item) }
  let(:variant) { double('Variant', id: variant_id) }
  let(:variant_id) { 2 }
  let(:quantity) { 1 }

  before do
    allow(Spree::Variant).to receive(:find_by_id).with(variant_id)
      .and_return(variant)
  end

  shared_examples_for 'valid populator' do |errors|
    before do
      allow(contents).to receive(:add).and_return(line_item)
    end

    it 'returns true' do
      expect(subject.populate(variant_id, quantity)).to be(true)
    end

    it 'sets the object to be valid' do
      subject.populate(variant_id, quantity)
      expect(subject.valid?).to be(true)
    end

    it 'does not set error messages' do
      subject.populate(variant_id, quantity)
      expect(subject.errors.messages).to be_empty
    end

    it 'adds the variant to the order contents' do
      expect(contents).to receive(:add).with(variant, quantity, 'USD')
        .and_return(line_item)
      subject.populate(variant_id, quantity)
    end
  end

  shared_examples_for 'invalid populator' do |errors|
    it 'returns false' do
      expect(subject.populate(variant_id, quantity)).to be(false)
    end

    it 'sets the object to be invalid' do
      subject.populate(variant_id, quantity)
      expect(subject.valid?).to be(false)
    end

    it 'sets the expected error messages' do
      subject.populate(variant_id, quantity)
      expect(subject.errors.messages).to eql(base: errors)
    end
  end

  shared_examples_for 'skips adding to the order contents' do
    it 'should not add the variant to the order contents' do
      expect(contents).to_not receive(:add)
      subject.populate(variant_id, quantity)
    end
  end

  describe '#populate' do
    context 'with an unknown variant' do
      let(:variant) { nil }

      include_examples 'skips adding to the order contents'
      include_examples 'invalid populator', [
        'Please specify a valid variant.'
      ]
    end

    context 'with a quantity less than 0' do
      let(:quantity) { -1 }

      include_examples 'skips adding to the order contents'
      include_examples 'invalid populator', [
        'Please enter a reasonable quantity.'
      ]
    end

    context 'with a quantity equal to 0' do
      let(:quantity) { 0 }

      include_examples 'skips adding to the order contents'
      include_examples 'invalid populator', [
        'Please enter a quantity greater than 0.'
      ]
    end

    context 'with a quantity greater than 0' do
      include_examples 'valid populator'
    end

    context 'with a quantity equal to 2_147_483_647' do
      let(:quantity) { 2_147_483_647 }

      include_examples 'valid populator'
    end

    context 'with a quantity greater than 2_147_483_647' do
      let(:quantity) { 2_147_483_648 }

      include_examples 'skips adding to the order contents'
      include_examples 'invalid populator', [
        'Please enter a reasonable quantity.'
      ]
    end

    context 'with a variant matching a line item' do
      let(:line_items) { [line_item] }

      before do
        # Force the existing line item variant_id to match
        expect(line_item).to receive_messages(
          variant_id: variant_id,
          variant:    variant
        )
      end

      it 'does not query the variant' do
        expect(Spree::Variant).to_not receive(:find_by_id)
        subject.populate(variant_id, quantity)
      end

      include_examples 'valid populator'
    end

    context 'with a variant not matching a line item' do
      let(:line_items) { [line_item] }

      before do
        # Force the existing line item variant_id to not match
        expect(line_item).to receive(:variant_id).and_return(3)
        expect(line_item).to_not receive(:variant)
      end

      it 'queries the variant' do
        expect(Spree::Variant).to receive(:find_by_id).with(variant_id)
          .and_return(variant)
        subject.populate(variant_id, quantity)
      end

      include_examples 'valid populator'
    end

    context 'with an invalid line item' do
      let(:errors) do
        ActiveModel::Errors.new(line_item).tap do |errors|
          errors.add(:base, 'Error #1')
          errors.add(:base, 'Error #2')
        end
      end

      before do
        expect(line_item).to receive(:errors).and_return(errors)
        expect(line_item).to receive(:valid?).and_return(false)
      end

      include_examples 'invalid populator', [
        'Error #1 Error #2'
      ]
    end

    context 'with multiple errors' do
      let(:quantity) { 0   }
      let(:variant)  { nil }

      include_examples 'skips adding to the order contents'
      include_examples 'invalid populator', [
        'Please specify a valid variant.',
        'Please enter a quantity greater than 0.'
      ]
    end
  end

  describe '#valid?' do
    context 'when there are no errors' do
      its(:valid?) { should be(true) }
    end

    context 'when there are no errors' do
      before do
        subject.errors.add(:base, 'Error')
      end

      its(:valid?) { should be(false) }
    end
  end
end
