require 'spec_helper'

module Spree
  describe Classification do
    # Regression test for #3494
    it "cannot link the same taxon to the same product more than once" do
      product = create(:product)
      taxon = create(:taxon)
      add_taxon = lambda { product.taxons << taxon }
      add_taxon.should_not raise_error
      add_taxon.should raise_error(ActiveRecord::RecordInvalid)
    end

  end
end