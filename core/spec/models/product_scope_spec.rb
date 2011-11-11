require 'spec_helper'

describe Spree::ProductScope do

  context "validations" do
    #it { should have_valid_factory(:product_scope) }
  end

  # FIXME use factory in the following test
  context "#check_validity_of_scope" do
    before do
      @pg = Factory(:product_group)
      #@ps = Spree::ProductScope.create(:name => 'in_name', :arguments => ['Rails'], :product_group_id => @pg.id)
    end
    it 'should be valid' do
      pending
      @pg.valid?.should be_true
    end

  end

  describe "#products" do
    context "with an existing Product scope" do
      it "sends an eponymous message to Product" do
        Spree::Product.should_receive(:master_price_lte).with('100')
        subject.name = 'master_price_lte'
        subject.arguments = ['100']
        subject.products
      end
    end

    context "with a non-existent Product scope" do
      it "should return nil" do
        subject.name = 'dlghdskjhgsjkg'
        subject.products.should be_nil
      end
    end
  end

end
