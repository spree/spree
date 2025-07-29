require 'spec_helper'

RSpec.describe Spree::Metafield, type: :model do
  let(:product) { create(:product) }
  
  describe 'validations' do
    subject { build(:metafield, owner: product) }
    
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_presence_of(:visibility) }
    it { is_expected.to validate_presence_of(:kind) }
    
    it { is_expected.to validate_inclusion_of(:visibility).in_array(%w[public private]) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[string integer boolean json]) }
    
    it 'validates uniqueness of key within owner and visibility' do
      create(:metafield, owner: product, key: 'color', visibility: 'public')
      duplicate = build(:metafield, owner: product, key: 'color', visibility: 'public')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include('has already been taken')
    end
  end
  
  describe 'associations' do
    it { is_expected.to belong_to(:owner) }
  end
  
  describe 'scopes' do
    let!(:public_metafield) { create(:metafield, owner: product, visibility: 'public') }
    let!(:private_metafield) { create(:metafield, owner: product, visibility: 'private') }
    
    describe '.public_metafields' do
      it 'returns only public metafields' do
        expect(Spree::Metafield.public_metafields).to include(public_metafield)
        expect(Spree::Metafield.public_metafields).not_to include(private_metafield)
      end
    end
    
    describe '.private_metafields' do
      it 'returns only private metafields' do
        expect(Spree::Metafield.private_metafields).to include(private_metafield)
        expect(Spree::Metafield.private_metafields).not_to include(public_metafield)
      end
    end
    
  end
  
  describe '#value=' do
    context 'when kind is integer' do
      subject { build(:metafield, kind: 'integer') }
      
      it 'converts value to integer' do
        subject.value = '42'
        expect(subject.value).to eq(42)
      end
    end
    
    context 'when kind is boolean' do
      subject { build(:metafield, kind: 'boolean') }
      
      it 'converts string "true" to boolean' do
        subject.value = 'true'
        expect(subject.value).to be(true)
      end
      
      it 'converts string "false" to boolean' do
        subject.value = 'false'
        expect(subject.value).to be(false)
      end
    end
    
    context 'when kind is json' do
      subject { build(:metafield, kind: 'json') }
      
      it 'parses valid JSON string' do
        subject.value = '{"key": "value"}'
        expect(subject.value).to eq('key' => 'value')
      end
      
      it 'handles invalid JSON gracefully' do
        subject.value = 'invalid json'
        expect(subject.value).to eq('invalid json')
      end
    end
    
    context 'when kind is string' do
      subject { build(:metafield, kind: 'string') }
      
      it 'converts value to string' do
        subject.value = 42
        expect(subject.value).to eq('42')
      end
    end
  end
  
  describe '#typed_value' do
    context 'when kind is integer' do
      subject { build(:metafield, kind: 'integer', value: '42') }
      
      it 'returns integer value' do
        expect(subject.typed_value).to eq(42)
      end
    end
    
    context 'when kind is boolean' do
      subject { build(:metafield, kind: 'boolean', value: 'true') }
      
      it 'returns boolean value' do
        expect(subject.typed_value).to be(true)
      end
    end
    
    context 'when kind is json' do
      subject { build(:metafield, kind: 'json', value: '{"key": "value"}') }
      
      it 'returns parsed JSON' do
        expect(subject.typed_value).to eq('key' => 'value')
      end
    end
    
    context 'when kind is string' do
      subject { build(:metafield, kind: 'string', value: 'test') }
      
      it 'returns string value' do
        expect(subject.typed_value).to eq('test')
      end
    end
  end
end