require 'spec_helper'

describe Spree::Products::TouchTaxonsJob, type: :job do
  describe '#perform' do
    subject { described_class.perform_now(taxon_ids, taxonomy_ids) }

    let!(:taxonomy) { create(:taxonomy) }
    let!(:taxon_1) { create(:taxon, taxonomy: taxonomy) }
    let!(:taxon_2) { create(:taxon, taxonomy: taxonomy) }
    let!(:other_taxon) { create(:taxon) }

    let(:taxon_ids) { [taxon_1.id, taxon_2.id] }
    let(:taxonomy_ids) { [taxonomy.id] }

    it 'touches all specified taxons' do
      expect { subject }.to change { Spree::Taxon.where(id: taxon_ids).pluck(:updated_at) }
    end

    it 'touches all specified taxonomies' do
      expect { subject }.to change { Spree::Taxonomy.where(id: taxonomy_ids).pluck(:updated_at) }
    end

    it 'does not touch other taxons' do
      expect { subject }.not_to change { other_taxon.reload.updated_at }
    end
  end
end
