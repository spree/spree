require 'spec_helper'

describe Spree::RichTextSanitizer do
  subject { described_class.sanitize(html) }

  describe '.sanitize' do
    # The allowlist is scoped to what the dashboard's Tiptap editor emits, so
    # its own output has to survive untouched — a sanitizer that rewrites the
    # editor's markup would corrupt content on every save.
    context 'with editor output' do
      {
        'paragraphs and marks' => '<p>a <strong>b</strong> <em>c</em> <s>d</s> <u>e</u> <code>f</code></p>',
        'headings' => '<h1>1</h1><h2>2</h2><h3>3</h3><h4>4</h4><h5>5</h5><h6>6</h6>',
        'lists' => '<ul><li><p>a</p></li></ul><ol><li><p>b</p></li></ol>',
        'blockquote' => '<blockquote><p>q</p></blockquote>',
        'code block' => '<pre><code>x = 1</code></pre>',
        'code block with a language' => '<pre><code class="language-ruby">x = 1</code></pre>',
        'rules and hard breaks' => '<hr><p>a<br>b</p>',
        'links' => '<p><a href="https://example.com" target="_blank" rel="noopener" title="t">l</a></p>'
      }.each do |description, markup|
        context "with #{description}" do
          let(:html) { markup }

          it { is_expected.to eq(markup) }
        end
      end
    end

    context 'with a script tag' do
      let(:html) { '<p>safe</p><script>alert(1)</script>' }

      it { is_expected.to eq('<p>safe</p>') }
    end

    context 'with a style tag' do
      let(:html) { '<p>safe</p><style>body { color: red }</style>' }

      it 'drops the stylesheet rather than leaving it as visible text' do
        expect(subject).to eq('<p>safe</p>')
      end
    end

    context 'with event handler attributes' do
      let(:html) { '<p onclick="steal()">x</p>' }

      it { is_expected.to eq('<p>x</p>') }
    end

    context 'with a javascript: URL' do
      let(:html) { '<a href="javascript:alert(1)">x</a>' }

      it { is_expected.not_to include('javascript:') }
    end

    context 'with inline styles' do
      let(:html) { '<p style="position: fixed; top: 0">overlay</p>' }

      it 'drops style entirely — the editor emits none, and it enables overlays' do
        expect(subject).to eq('<p>overlay</p>')
      end
    end

    context 'with a class the editor never emits' do
      let(:html) { '<p class="storefront-checkout-button">x</p>' }

      it { is_expected.to eq('<p>x</p>') }
    end

    context 'with an extra class alongside a code language' do
      let(:html) { '<pre><code class="language-ruby injected">x</code></pre>' }

      it 'keeps the language hint and drops the rest' do
        expect(subject).to eq('<pre><code class="language-ruby">x</code></pre>')
      end
    end

    # The language hint is a code-block concern, so it must not double as a way
    # to put a class on arbitrary markup.
    context 'with a language class on something other than code' do
      let(:html) { '<p class="language-ruby">x</p><a href="/y" class="language-js">z</a>' }

      it { is_expected.to eq('<p>x</p><a href="/y">z</a>') }
    end

    # Legacy TinyMCE descriptions carry markup the Tiptap set has no node for.
    # Formatting is lost on the next save, but the words are not.
    context 'with legacy markup outside the editor set' do
      let(:html) { '<div><span>kept</span></div><table><tr><td>cell</td></tr></table>' }

      it 'unwraps the tags and preserves the text' do
        expect(subject).to eq('keptcell')
      end
    end

    context 'with an image' do
      let(:html) { '<p>a</p><img src="https://example.com/a.png" alt="a">' }

      it { is_expected.to eq('<p>a</p>') }

      context 'when img is added to the allowlist' do
        around do |example|
          original_tags = described_class.allowed_tags
          original_attributes = described_class.allowed_attributes
          described_class.allowed_tags = original_tags + %w[img]
          described_class.allowed_attributes = original_attributes + %w[src alt]
          example.run
          described_class.allowed_tags = original_tags
          described_class.allowed_attributes = original_attributes
        end

        it { is_expected.to include('src="https://example.com/a.png"', 'alt="a"') }
      end
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

    context 'when blank' do
      it { expect(described_class.sanitize(nil)).to be_nil }
      it { expect(described_class.sanitize('')).to eq('') }
    end
  end
end
