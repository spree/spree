require 'spec_helper'

describe 'product scopes' do
  context 'finds products filtered by taxon' do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root
      @parent_taxon = create(:taxon, name: 'Parent', :taxonomy_id => @taxonomy.id, :parent => @root_taxon)
      @child1_taxon = create(:taxon, name: 'Child 1', :taxonomy_id => @taxonomy.id, :parent => @parent_taxon)
      @child2_taxon = create(:taxon, name: 'Child 2', :taxonomy_id => @taxonomy.id, :parent => @parent_taxon)
      @parent_taxon.reload # Need to reload for descendents to show up

      @product = create(:product, taxons: [@child1_taxon, @child2_taxon])
    end

    # Issue #1917
    it "should not duplicates products appearing in multiple descendents" do
      Spree::Product.active.in_taxon(@parent_taxon).should include @product
      Spree::Product.active.in_taxon(@parent_taxon).size.should eq 1
    end

  end
end
