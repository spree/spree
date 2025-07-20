require 'spec_helper'

RSpec.describe Spree::Import, type: :model, job: true, import: true do
  subject(:import) { build(:import, type: type, store: store, user: user, attachment: file, error_details: errors, total_count: total, processed_count: processed) }
  
  let(:store) { create(:store, code: 'my-store') }
  let(:user) { create(:admin_user) }
  let(:file) { file_fixture('import/products_valid.csv') }
  let(:errors) { {} }
  let(:total) { nil }
  let(:processed) { nil }
  let(:type) { 'Spree::Imports::Products' }

  context 'Validation' do
    context 'with valid params' do
      it { is_expected.to be_valid }
    end

    context 'without attachment' do
      let(:file) { nil }

      it { is_expected.to be_invalid }
    end

    context 'without store' do
      let(:store) { nil }
      
      it { is_expected.to be_invalid }
    end

    context 'with invalid file (not a csv file)' do
      let(:file) { file_fixture('icon_256x256.gif') }

      it { is_expected.to be_invalid }
    end
  end

  describe '#remaining' do
    subject(:remaining) { import.remaining }

    context 'when not executed' do
      it { is_expected.to be_nil }
    end

    context 'when processing' do
      let(:total) { 1000 }
      let(:errors) { { 'one_with' => "error" } }
      let(:processed) { 500 }

      it 'returns valid number' do
        expect(remaining).to eq(499)
      end
    end
  end
end
