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
  end

end
