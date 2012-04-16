require 'spec_helper'

describe Spree::Taxonomy do

  context "validation" do
    it { should have_valid_factory(:taxonomy) }
  end

  context "#destroy" do
    before do
       @taxonomy = Factory(:taxonomy)
       @root_taxon = @taxonomy.root
       @child_taxon = Factory(:taxon, :taxonomy_id => @taxonomy.id, :parent => @root_taxon)
    end

    it "should destroy all associated taxons" do
      @taxonomy.destroy
      expect{ Spree::Taxon.find(@root_taxon.id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect{ Spree::Taxon.find(@child_taxon.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

