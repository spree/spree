require 'spec_helper'

module Spree
  describe BaseHelper, :type => :helper do
    # Regression test for #2759
    it "nested_taxons_path works with a Taxon object" do
      taxon = create(:taxon, :name => "iphone")
      expect(spree.nested_taxons_path(taxon)).to eq("/t/iphone")
    end
  end
end
