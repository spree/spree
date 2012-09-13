require 'spec_helper'

describe "Product scopes" do
  let!(:product) { create(:product) }
  
  context "A product assigned to parent and child taxons" do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root
      
      @taxon = create(:taxon, :name => 'A1', :taxonomy_id => @taxonomy.id)
      @taxon2 = create(:taxon, :name => 'A2', :taxonomy_id => @taxonomy.id)
      
      @taxon.move_to_child_of(@root_taxon)
      @taxon2.move_to_child_of(@taxon)
      
      product.taxons << @taxon
      product.taxons << @taxon2
    end
    
    it "calling Product.in_taxon should not return duplicate records" do
      Spree::Product.in_taxon(@taxon).length.should == 1
    end
  end
end
