require 'spec_helper'

describe Spree::RichTextSanitizer do
  subject { described_class.sanitize(html) }

  describe '.sanitize' do
    context 'with a script tag' do
      let(:html) { '<p>safe</p><script>alert(1)</script>' }

      it { is_expected.not_to include('<script') }
      it { is_expected.to include('<p>safe</p>') }
    end

    context 'with event handler attributes' do
      let(:html) { '<img src="a.png" onerror="steal()"><div onclick="steal()">x</div>' }

      it { is_expected.not_to include('onerror') }
      it { is_expected.not_to include('onclick') }
    end

    context 'with a javascript: URL' do
      let(:html) { '<a href="javascript:alert(1)">x</a>' }

      it { is_expected.not_to include('javascript:') }
    end

    context 'with a link' do
      let(:html) { '<a href="https://example.com" target="_blank" rel="noopener">x</a>' }

      it { is_expected.to eq(html) }
    end

    context 'with table markup' do
      let(:html) { '<table><thead><tr><th colspan="2">h</th></tr></thead><tbody><tr><td rowspan="2">c</td></tr></tbody></table>' }

      it { is_expected.to eq(html) }
    end

    context 'with an image' do
      let(:html) { '<img src="https://example.com/a.png" alt="a" width="10" height="20">' }

      it { is_expected.to include('src="https://example.com/a.png"', 'alt="a"', 'width="10"', 'height="20"') }
    end

    context 'with an iframe' do
      let(:html) { '<iframe src="https://example.com/video"></iframe>' }

      it { is_expected.not_to include('<iframe') }

      context 'when iframe is added to the allowlist' do
        around do |example|
          original = described_class.allowed_tags
          described_class.allowed_tags = original + %w[iframe]
          example.run
          described_class.allowed_tags = original
        end

        it { is_expected.to include('<iframe') }
      end
    end

    context 'with inline styles' do
      let(:html) { '<p style="color: red; position: fixed">x</p>' }

      it 'keeps allowed CSS properties and drops the rest' do
        expect(subject).to include('color:red')
        expect(subject).not_to include('position')
      end
    end

    context 'when blank' do
      it { expect(described_class.sanitize(nil)).to be_nil }
      it { expect(described_class.sanitize('')).to eq('') }
    end
  end
end
