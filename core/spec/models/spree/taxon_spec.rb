# coding: UTF-8

require 'spec_helper'

describe Spree::Taxon do
  let(:taxon) { Spree::Taxon.new(:name => "Ruby on Rails") }

  context "set_permalink" do

    it "should set permalink correctly when no parent present" do
      taxon.set_permalink
      taxon.permalink.should == "ruby-on-rails"
    end

    it "should support Chinese characters" do
      taxon.name = "你好"
      taxon.set_permalink
      taxon.permalink.should == 'ni-hao'
    end

    context "with parent taxon" do
      before do
        taxon.stub :parent_id => 123
        taxon.stub :parent => mock_model(Spree::Taxon, :permalink => "brands")
      end

      it "should set permalink correctly when taxon has parent" do
        taxon.set_permalink
        taxon.permalink.should == "brands/ruby-on-rails"
      end

      it "should set permalink correctly with existing permalink present" do
        taxon.permalink = "b/rubyonrails"
        taxon.set_permalink
        taxon.permalink.should == "brands/rubyonrails"
      end

      it "should support Chinese characters" do
        taxon.name = "我"
        taxon.set_permalink
        taxon.permalink.should == "brands/wo"
      end
    end
  end

  # Regression test for #2620
  context "creating a child node using first_or_create" do
    let(:taxonomy) { create(:taxonomy) }

    it "does not error out" do
      expect { taxonomy.root.children.where(:name => "Some name").first_or_create }.not_to raise_error
    end
  end

end
