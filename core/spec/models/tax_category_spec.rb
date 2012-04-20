require 'spec_helper'

describe Spree::TaxCategory do
  context "shoulda validations" do
    it { should have_many(:tax_rates) }
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:tax_category) }

    context 'uniquness validation' do
      before do
        Factory(:tax_category)
      end
      it { should validate_uniqueness_of(:name) }
    end

    context '#mark_deleted!' do
      let(:tax_category) { Factory(:tax_category) }

      it "should set the deleted at column to the current time" do
        tax_category.mark_deleted!
        tax_category.deleted_at.should_not be_nil
      end
    end
  end
  context 'default tax category' do
    let(:tax_category) { Factory(:tax_category) }
    let(:new_tax_category) { Factory(:tax_category) }

    before do
      tax_category.update_attribute(:is_default, true)
    end

    it "should undefault the previous default tax category" do
      new_tax_category.update_attribute(:is_default, true)
      new_tax_category.is_default.should be_true

      tax_category.reload
      tax_category.is_default.should be_false
    end

    it "should undefault the previous default tax category except when updating the existing default tax category" do
      tax_category.update_attribute(:description, "Updated description")

      tax_category.reload
      tax_category.is_default.should be_true
    end
  end
end
