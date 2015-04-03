require 'spec_helper'

describe Spree::TaxCategory, :type => :model do
  context 'default tax category' do
    let(:tax_category) { create(:tax_category) }
    let(:new_tax_category) { create(:tax_category) }

    before do
      tax_category.update_column(:is_default, true)
    end

    it "should undefault the previous default tax category" do
      new_tax_category.update_attributes({:is_default => true})
      expect(new_tax_category.is_default).to be true

      tax_category.reload
      expect(tax_category.is_default).to be false
    end

    it "should undefault the previous default tax category except when updating the existing default tax category" do
      tax_category.update_column(:description, "Updated description")

      tax_category.reload
      expect(tax_category.is_default).to be true
    end
  end

  context "#has_vat_rate_for_default_zone?" do
    let(:zone) { create(:zone_with_country, default_tax: true) }
    let(:tax_category) { create(:tax_category) }

    before do
      allow(Spree::Zone).to receive(:default_tax).and_return(zone)
    end

    subject {tax_category.has_vat_rate_for_default_zone? }

    context "when there is no vat rate in the default zone" do
      it "returns false" do
        expect(subject).to eq(false)
      end
    end

    context "when ther is a vat rate in the default zone" do
      before do
        create(
          :tax_rate,
          included_in_price: true,
          zone: zone,
          tax_category: tax_category
        )
      end
      it "returns true" do
        expect(subject).to eq(true)
      end
    end
  end
end
