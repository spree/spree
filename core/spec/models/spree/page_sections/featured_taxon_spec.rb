require 'spec_helper'

RSpec.describe Spree::PageSections::FeaturedTaxon do
  describe '.by_taxon_id' do
    let!(:taxons) { create_list(:taxon, 3) }

    let!(:featured_taxon_1) { create(:featured_taxon_page_section, preferred_taxon_id: taxons[0].id) }
    let!(:featured_taxon_2) { create(:featured_taxon_page_section, preferred_taxon_id: taxons[1].id) }

    it 'returns featured taxons by the taxon id' do
      expect(described_class.by_taxon_id(taxons[0].id)).to contain_exactly(featured_taxon_1)
      expect(described_class.by_taxon_id(taxons[2].id)).to be_empty

      expect(described_class.by_taxon_id([taxons[0].id, taxons[1].id])).to contain_exactly(featured_taxon_1, featured_taxon_2)
      expect(described_class.by_taxon_id([taxons[1].id, taxons[2].id])).to contain_exactly(featured_taxon_2)
    end
  end
end
