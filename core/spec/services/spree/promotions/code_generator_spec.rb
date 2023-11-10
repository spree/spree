require 'spec_helper'

module Spree
  describe Promotions::CodeGenerator do
    describe "#build" do
      let(:random_code) { 'secure_random_code' }
      let(:content) { "black_week" }

      before do
        allow(SecureRandom).to receive(:hex).with(4).and_return(random_code)
      end

      context "prefix" do
          let(:affix) { :prefix }

        it "creates a code with a given prefix" do
          code = described_class.new(content: content, affix: affix).build
          expect(code).to eq content.concat(random_code)
        end
      end

      context "suffix" do
        let(:affix) { :suffix }

        it "creates a code with a given suffix" do
          code = described_class.new(content: content, affix: affix).build
          expect(code).to eq random_code.concat(content)
        end
      end

      context "deny-list" do
        let(:forbidden_phrases) { %w(forbidden phrase) }
        let(:deny_list) { forbidden_phrases }

        before do
          allow(SecureRandom)
            .to receive(:hex).with(4)
            .and_return("foo_#{forbidden_phrases.first}_bar", "foo_#{forbidden_phrases.last}_bar", random_code)
        end

        it "discards code containing forbidden phrases" do
          code = described_class.new(content: content, deny_list: deny_list).build
          expect(code).to eq random_code
        end
      end

      context "default" do
        it "creates a code" do
          code = described_class.new.build
          expect(code).to eq random_code
        end
      end

      context "forbidden phrases contain the affix" do
        let(:forbidden_phrases) { %w(black_week) }
        let(:deny_list) { forbidden_phrases }
        let(:affix) { :prefix }

        it "returns an error" do
          expect {
            described_class.new(content: content, affix: affix, deny_list: deny_list).build
          }.to raise_error Spree::Promotions::CodeGenerator::MutuallyExclusiveInputsError
        end
      end

      context "runs out of retries" do
        let(:forbidden_phrases) { (1..100).map(&:to_s) }
        let(:deny_list) { forbidden_phrases }
        let(:code_candidates) { forbidden_phrases }

        before do
          allow(SecureRandom)
            .to receive(:hex).with(4)
            .and_return(*code_candidates)
        end

        it "returns an error" do
          expect {
            described_class.new(deny_list: deny_list).build
          }.to raise_error Spree::Promotions::CodeGenerator::RetriesDepleted
        end
      end
    end
  end
end
