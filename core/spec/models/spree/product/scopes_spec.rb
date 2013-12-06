require 'spec_helper'

describe "Product scopes" do
  let!(:product) { create(:product) }

  context "A product assigned to parent and child taxons" do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root

      @parent_taxon = create(:taxon, :name => 'Parent', :taxonomy_id => @taxonomy.id, :parent => @root_taxon)
      @child_taxon = create(:taxon, :name =>'Child 1', :taxonomy_id => @taxonomy.id, :parent => @parent_taxon)
      @parent_taxon.reload # Need to reload for descendents to show up

      product.taxons << @parent_taxon
      product.taxons << @child_taxon
    end

    it "calling Product.in_taxon should not return duplicate records" do
      Spree::Product.in_taxon(@parent_taxon).to_a.count.should == 1
    end
  end

  context '#add_simple_scopes' do
    let(:simple_scopes) { [:ascend_by_updated_at, :descend_by_name] }

    before do
      Spree::Product.add_simple_scopes(simple_scopes)
    end

    context 'define scope' do
      context 'ascend_by_updated_at' do
        context 'on class' do
          it { Spree::Product.ascend_by_updated_at.to_sql.should eq Spree::Product.order("#{Spree::Product.quoted_table_name}.updated_at ASC").to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { Spree::Product.limit(2).ascend_by_updated_at.to_sql.should eq Spree::Product.limit(2).order("#{Spree::Product.quoted_table_name}.updated_at ASC").to_sql }
          it { Spree::Product.limit(2).ascend_by_updated_at.to_sql.should eq Spree::Product.ascend_by_updated_at.limit(2).to_sql }
        end
      end

      context 'descend_by_name' do
        context 'on class' do
          it { Spree::Product.descend_by_name.to_sql.should eq Spree::Product.order("#{Spree::Product.quoted_table_name}.name DESC").to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { Spree::Product.limit(2).descend_by_name.to_sql.should eq Spree::Product.limit(2).order("#{Spree::Product.quoted_table_name}.name DESC").to_sql }
          it { Spree::Product.limit(2).descend_by_name.to_sql.should eq Spree::Product.descend_by_name.limit(2).to_sql }
        end
      end
    end
  end
end
