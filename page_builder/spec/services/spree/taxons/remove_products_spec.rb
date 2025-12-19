require 'spec_helper'

module Spree
  describe Taxons::RemoveProducts do
    let(:service) { described_class }
    let(:taxons) { create_list(:taxon, 2) }
    let(:products) { create_list(:product, 3) }
    let!(:featured_sections) { create_list(:featured_taxon_page_section, 2, preferred_taxon_id: taxons.first.id) }

    describe '#call' do
      subject { service.call(taxons: taxons, products: products) }

      before do
        # Add products to taxons initially
        Spree::Taxons::AddProducts.call(taxons: taxons, products: products)
      end

      it 'touches all featured sections' do
        expect { subject }.to change { Spree::PageSections::FeaturedTaxon.where(id: featured_sections.pluck(:id)).pluck(:updated_at) }
      end
    end
  end
end
