require File.dirname(__FILE__) + '/../spec_helper'

describe ProductGroup do

  context "validations" do
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:product_group) }
  end
  
  describe '#from_route' do
    context "wth valid scopes" do
      before do 
        subject.from_route(["master_price_lte", "100", "in_name_or_keywords", "Ikea", "ascend_by_master_price"])
      end
      
      it "sets one ordering scope" do
        subject.product_scopes.select(&:is_ordering?).length.should == 1
      end
      
      it "sets two non-ordering scopes" do
        subject.product_scopes.reject(&:is_ordering?).length.should == 2
      end
    end
        
    context 'with an invalid product scope' do
      before do 
        subject.from_route(["master_pri_lte", "100", "in_name_or_kerds", "Ikea"])
      end
      
      it 'sets no product scopes' do
        subject.product_scopes.should be_empty
      end
    end
       
  end
end