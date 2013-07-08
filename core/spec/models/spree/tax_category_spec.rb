require 'spec_helper'

describe Spree::TaxCategory do
  context 'default tax category' do
    let(:tax_category) { create(:tax_category) }
    let(:new_tax_category) { create(:tax_category) }

    before do
      tax_category.update_column(:is_default, true)
    end

    it "should undefault the previous default tax category" do
      new_tax_category.update_attributes({:is_default => true})
      new_tax_category.is_default.should be_true

      tax_category.reload
      tax_category.is_default.should be_false
    end

    it "should undefault the previous default tax category except when updating the existing default tax category" do
      tax_category.update_column(:description, "Updated description")

      tax_category.reload
      tax_category.is_default.should be_true
    end
  end
end
