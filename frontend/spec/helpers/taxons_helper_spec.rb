require 'spec_helper'

describe Spree::TaxonsHelper, type: :helper do
  # Regression test for #4382
  it '#taxon_preview' do
    taxon = create(:taxon)
    child_taxon = create(:taxon, parent: taxon)
    product_1 = create(:product)
    product_2 = create(:product)
    product_3 = create(:product)
    taxon.products << product_1
    taxon.products << product_2
    child_taxon.products << product_3

    expect(taxon_preview(taxon.reload)).to eql([product_1, product_2, product_3])
  end
end
