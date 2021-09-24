require 'spec_helper'

describe Spree::Relation, type: :model do
  subject { relation }

  let(:relation) { build(:relation, relatable: product, related_to: related_to, relation_type: relation_type, discount_amount: 1.0) }
  let(:product) { create(:product) }
  let(:related_to) { create(:product) }
  let(:relation_type) { create(:relation_type) }

  describe 'associations' do
    describe '#relation_type' do
      it 'belongs to relation type' do
        expect(subject.relation_type).to eq relation_type
      end
    end

    describe '#relatable' do
      it 'belongs to relatable' do
        expect(subject.relatable).to eq product
      end
    end

    describe '#relation_type' do
      it 'belongs to relation type' do
        expect(subject.relation_type).to eq relation_type
      end
    end
  end

  describe 'validations' do
    shared_examples 'valid' do
      it 'is valid' do
        expect(subject.valid?).to be true
      end
    end

    shared_examples 'not valid' do
      it 'is not valid' do
        expect(subject.valid?).to be false
      end
    end

    describe 'relation_type' do
      context 'when is present' do
        it_behaves_like 'valid'
      end

      context 'when is nil' do
        let(:relation_type) { nil }

        it_behaves_like 'not valid'
      end
    end

    describe 'relatable' do
      context 'when is present' do
        it_behaves_like 'valid'
      end

      context 'when is nil' do
        let(:product) { nil }

        it_behaves_like 'not valid'
      end
    end

    describe 'related_to' do
      context 'when is present' do
        it_behaves_like 'valid'
      end

      context 'when is nil' do
        let(:related_to) { nil }

        it_behaves_like 'not valid'
      end
    end
  end
end
