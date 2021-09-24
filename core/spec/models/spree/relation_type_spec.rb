require 'spec_helper'

describe Spree::RelationType, type: :model do
  subject { relation_type }

  let(:name) { generate(:random_string) }
  let(:applies_to) { 'Spree::Product' }
  let!(:relation) { create(:relation, relation_type: relation_type) }

  describe 'associations' do
    let(:relation_type) { create(:relation_type, name: name, applies_to: applies_to) }

    describe '#relations' do
      it 'can have many relations' do
        expect(subject.relations).to match_array [relation]
      end

      context 'when destroyed' do
        before { subject.destroy! }

        it 'destroys related relations' do
          expect(Spree::Relation.find_by(id: relation.id)).to be nil
        end
      end
    end
  end

  describe 'validations' do
    let(:relation_type) { build(:relation_type, name: name, applies_to: applies_to) }

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

    describe 'name' do
      context 'when is present' do
        it_behaves_like 'valid'
      end

      context 'when is nil' do
        let(:name) { nil }

        it_behaves_like 'not valid'
      end

      context 'when unique' do
        it_behaves_like 'valid'
      end

      context 'when is not unique' do
        let(:some_relation_type) { create(:relation_type) }
        let(:name) { some_relation_type.name }

        it_behaves_like 'not valid'
      end

      context 'uniqueness is not case sensitive' do
        let(:some_relation_type) { create(:relation_type) }
        let(:name) { some_relation_type.name }

        before { subject.name = subject.name.upcase }

        it_behaves_like 'not valid'
      end
    end

    describe 'applies_to' do
      context 'when is present' do
        it_behaves_like 'valid'
      end

      context 'when is nil' do
        let(:applies_to) { nil }

        it_behaves_like 'not valid'
      end
    end
  end
end
