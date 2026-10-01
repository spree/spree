require 'spec_helper'

describe Spree::Emails::InvisibleTextCheck do
  def check(source, top_level_shown: true)
    described_class.call(source, top_level_shown: top_level_shown)
  end

  it 'finds text written straight into a section, column or the email body, with its line' do
    source = "<mj-section>\n  <mj-column>\n    lost in a column\n    <mj-text>shown</mj-text>\n  </mj-column>\n</mj-section>\nlost at the top"

    expect(check(source)).to eq([{ line: 3, text: 'lost in a column' }, { line: 7, text: 'lost at the top' }])
  end

  it 'accepts text inside content components, including their HTML' do
    source = "<mj-section><mj-column><mj-text><p>Hi <b>{{ name }}</b></p></mj-text>" \
             "<mj-button href=\"#\">Go</mj-button><mj-table><tr><td>Row</td></tr></mj-table></mj-column></mj-section>"

    expect(check(source)).to eq([])
  end

  it 'ignores Liquid that prints nothing or prints components' do
    source = "{% capture heading %}Order {{ order.number }}{% endcapture %}\n{% if x %}{% endif %}\n{{ content_for_layout }}\n" \
             "{% render 'spree/shared/order_summary', heading: heading %}"

    expect(check(source)).to eq([])
  end

  it 'leaves text at the top of a partial alone, since the partial decides nothing about where it is rendered' do
    expect(check('<tr><td>Subtotal</td></tr>', top_level_shown: false)).to eq([])
  end

  it 'finds none in the templates Spree ships' do
    Dir[Spree::Core::Engine.root.join('app/views/**/*.liquid')].each do |path|
      expect(check(File.read(path), top_level_shown: false)).to eq([]), path
    end
  end
end
