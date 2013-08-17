require 'spec_helper'

describe Spree::Admin::TaxonsController do
  stub_authorization!

  # Regression test for #2747
  it "can delete a taxon" do
    taxon = create(:taxon)
    spree_delete :destroy, :id => taxon.id
    response.status.should == 204
  end
end
