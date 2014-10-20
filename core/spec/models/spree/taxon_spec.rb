# coding: UTF-8

require 'spec_helper'

describe Spree::Taxon, :type => :model do
  let(:taxon) { FactoryGirl.build(:taxon, :name => "Ruby on Rails") }

  describe '#to_param' do
    subject { super().to_param }
    it { is_expected.to eql taxon.permalink }
  end

  context "set_permalink" do

    it "should set permalink correctly when no parent present" do
      taxon.set_permalink
      expect(taxon.permalink).to eql "ruby-on-rails"
    end

    it "should support Chinese characters" do
      taxon.name = "你好"
      taxon.set_permalink
      expect(taxon.permalink).to eql 'ni-hao'
    end

    context "with parent taxon" do
      let(:parent) { FactoryGirl.build(:taxon, :permalink => "brands") }
      before       { allow(taxon).to receive_messages parent: parent }

      it "should set permalink correctly when taxon has parent" do
        taxon.set_permalink
        expect(taxon.permalink).to eql "brands/ruby-on-rails"
      end

      it "should set permalink correctly with existing permalink present" do
        taxon.permalink = "b/rubyonrails"
        taxon.set_permalink
        expect(taxon.permalink).to eql "brands/rubyonrails"
      end

      it "should support Chinese characters" do
        taxon.name = "我"
        taxon.set_permalink
        expect(taxon.permalink).to eql "brands/wo"
      end

      # Regression test for #3390
      context "setting a new node sibling position via :child_index=" do
        let(:idx) { rand(0..100) }
        before { allow(parent).to receive(:move_to_child_with_index) }

        context "taxon is not new" do
          before { allow(taxon).to receive(:new_record?).and_return(false) }

          it "passes the desired index move_to_child_with_index of :parent " do
            expect(taxon).to receive(:move_to_child_with_index).with(parent, idx)

            taxon.child_index = idx
          end
        end
      end

    end
  end

  # Regression test for #2620
  context "creating a child node using first_or_create" do
    let(:taxonomy) { create(:taxonomy) }

    it "does not error out" do
      expect { taxonomy.root.children.unscoped.where(:name => "Some name").first_or_create }.not_to raise_error
    end
  end
end
