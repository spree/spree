require 'spec_helper'

describe "Product scopes" do
  let!(:product) { create(:product) }

  context "A product assigned to parent and child taxons" do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root

      @parent_taxon = create(:taxon, :name => 'Parent', :taxonomy_id => @taxonomy.id, :parent => @root_taxon)
      @child_taxon = create(:taxon, :name =>'Child 1', :taxonomy_id => @taxonomy.id, :parent => @parent_taxon)
      @parent_taxon.reload # Need to reload for descendents to show up

      product.taxons << @parent_taxon
      product.taxons << @child_taxon
    end

    it "calling Product.in_taxon should not return duplicate records" do
      Spree::Product.in_taxon(@parent_taxon).to_a.should == 1
    end
  end
end
