require 'spec_helper'

RSpec.describe Spree::RichTextHelper do
  describe '.to_plain_text' do
    subject { described_class.to_plain_text(html) }

    context 'when blank' do
      let(:html) { nil }

      it { is_expected.to eq('') }
    end

    context 'with a single paragraph' do
      let(:html) { '<p>A <strong>comfortable</strong> cotton t-shirt.</p>' }

      it 'strips tags without trailing whitespace' do
        is_expected.to eq('A comfortable cotton t-shirt.')
      end
    end

    context 'with multiple blocks' do
      let(:html) { '<p>Need to install the following packages:</p><p>create-spree-app@1.1.2</p>' }

      it 'separates adjacent blocks with a newline instead of gluing them' do
        is_expected.to eq("Need to install the following packages:\ncreate-spree-app@1.1.2")
      end
    end

    context 'with hard line breaks and lists' do
      let(:html) { '<p>First<br>Second</p><ul><li>One</li><li>Two</li></ul>' }

      it 'preserves line breaks and list item boundaries' do
        is_expected.to eq("First\nSecond\nOne\nTwo")
      end
    end

    context 'with pretty-printed source HTML (legacy TinyMCE, imports)' do
      let(:html) { "<p>Hello\n  world</p>\n<p>Second</p>" }

      it 'renders source newlines as spaces, like a browser' do
        is_expected.to eq("Hello world\nSecond")
      end
    end
  end
end
