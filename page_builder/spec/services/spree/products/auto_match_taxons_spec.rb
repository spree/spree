require 'spec_helper'

RSpec.describe Spree::Products::AutoMatchTaxons do
  subject { described_class.call(product: product) }

  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }

  context 'for a featured taxon' do
    let!(:taxon) { create(:automatic_taxon, taxonomy: store.taxonomies.first) }
    let!(:featured_taxon) { Spree::PageSections::FeaturedTaxon.create!(pageable: Spree::Page.find_by(name: 'Homepage')) }

    before do
      create(:tag_taxon_rule, taxon: taxon, value: 'cruelty-free')
      product.tag_list.add('cruelty-free')
      product.save

      featured_taxon.update!(preferred_taxon_id: taxon.id)
    end

    it 'refreshes the featured taxon' do
      expect { subject }.to change { featured_taxon.reload.updated_at }
    end
  end
end
