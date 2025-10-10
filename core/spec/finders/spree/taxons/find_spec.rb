require 'spec_helper'

module Spree
  describe Taxons::Find do
    let!(:taxon_shirts) { create(:taxon, name: 'Shirts') }
    let!(:taxon_shorts) { create(:taxon, name: 'Shorts') }
    let!(:taxon_shoes)  { create(:taxon, name: 'Shoes') }

    describe 'filtering by taxon property' do
      subject do
        described_class.new(
          scope: Spree::Taxon.all,
          params: params
        ).execute
      end

      context 'when filtering by taxon name' do
        let(:params) { { filter: { 'name': 'Shirts' } } }

        it 'returns taxon with matching name' do
          expect(subject).to contain_exactly(taxon_shirts)
        end
      end

    end

  end
end
