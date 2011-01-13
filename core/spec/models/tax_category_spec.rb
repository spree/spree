require File.dirname(__FILE__) + '/../spec_helper'

describe TaxCategory do
  context "shoulda validations" do
    it { should have_many(:tax_rates) }
    it { should validate_presence_of(:name) }

    context 'uniquness validation' do
      before do
        Factory(:tax_category)
      end
      it { should validate_uniqueness_of(:name) }
    end
  end

  context "factory_girl" do
    specify { Factory(:tax_category).new_record?.should be_false }
  end

  context 'before_save' do
    let!(:tax_category1) { Factory(:tax_category, :is_default => true) }
    let!(:tax_category2) { Factory(:tax_category, :is_default => true, :name => 'Sports') }
    it "tax_category1 should not be default" do
      tax_category1.reload.is_default.should be_false
    end
    it "tax_category2 should be default" do
      tax_category2.reload.is_default.should be_true
    end
  end

end
