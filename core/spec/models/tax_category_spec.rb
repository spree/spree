require 'spec_helper'

describe Spree::TaxCategory do
  context '#mark_deleted!' do
    let(:tax_category) { Factory(:tax_category) }

    it "should set the deleted at column to the current time" do
      tax_category.mark_deleted!
      tax_category.deleted_at.should_not be_nil
    end
  end
end
