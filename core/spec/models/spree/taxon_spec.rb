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
        taxon.stub(:parent_id => 123)
        Spree::Taxon.should_receive(:find).with(123).and_return(mock_model(Spree::Taxon, :permalink => "brands"))
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

end
