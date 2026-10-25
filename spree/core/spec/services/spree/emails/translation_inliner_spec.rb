require 'spec_helper'

describe Spree::Emails::TranslationInliner do
  def inline(source, locale: :en, escape: true)
    described_class.call(source, locale: locale, escape: escape)
  end

  around do |example|
    I18n.backend.store_translations(:en, spree: { inliner_spec: {
      plain: 'Thanks for shopping',
      greeting: 'Dear %{name},',
      heading: 'Order %{number} summary',
      markup: 'Tom & Jerry <shop>',
      quoted: "Don't wait",
      count: { one: 'One item', other: '%{count} items' }
    } })
    I18n.backend.store_translations(:de, spree: { inliner_spec: { plain: 'Danke für Ihren Einkauf' } })
    example.run
  end

  it 'writes a key out as text in the language asked for' do
    expect(inline("<mj-text>{{ 'inliner_spec.plain' | t }}</mj-text>")).to eq('<mj-text>Thanks for shopping</mj-text>')
    expect(inline("{{ 'inliner_spec.plain' | t }}", locale: :de)).to eq('Danke für Ihren Einkauf')
  end

  it 'turns each value into the variable the template passed' do
    expect(inline("{{ 'inliner_spec.greeting' | t: name: order.customer_name }}")).to eq('Dear {{ order.customer_name }},')
  end

  it 'escapes the text, since the filter output was escaped' do
    expect(inline("{{ 'inliner_spec.markup' | t }}")).to eq('Tom &amp; Jerry &lt;shop&gt;')
  end

  it 'leaves text unescaped for a subject, which renders as a plain mail header' do
    expect(inline("{{ 'inliner_spec.quoted' | t }} & more", escape: false)).to eq("Don't wait & more")
  end

  it 'keeps later filters on text without values' do
    expect(inline("{{ 'inliner_spec.plain' | t | upcase }}")).to eq("{{ 'Thanks for shopping' | upcase }}")
  end

  it 'turns an assigned translation into a plain assignment or a capture' do
    expect(inline("{% assign heading = 'inliner_spec.plain' | t %}")).to eq("{% assign heading = 'Thanks for shopping' %}")
    expect(inline("{% assign heading = 'inliner_spec.heading' | t: number: order.number %}")).
      to eq('{% capture heading %}Order {{ order.number }} summary{% endcapture %}')
    expect(inline("{% assign label = 'inliner_spec.quoted' | t %}")).to eq('{% capture label %}Don&#39;t wait{% endcapture %}')
  end

  it 'leaves what it cannot write out exactly as it was' do
    [
      "{{ 'inliner_spec.count' | t: count: n }}",
      "{{ 'inliner_spec.greeting' | t }}",
      "{{ 'inliner_spec.missing' | t }}",
      "{{ 'inliner_spec.greeting' | t: name: user.name | upcase }}"
    ].each { |source| expect(inline(source)).to eq(source) }
  end

  it 'renders the same as the template it came from' do
    store = @default_store
    source = "{% assign label = 'inliner_spec.quoted' | t %}<mj-section><mj-column><mj-text>{{ 'inliner_spec.greeting' | t: name: name }} {{ label }} {{ 'inliner_spec.markup' | t }}</mj-text></mj-column></mj-section>"
    resolver = Spree::Emails::TemplateResolver.for_mailers
    renderer = Spree::Emails::Renderer.new(resolver: resolver, store: store)
    original = renderer.render(Spree::Emails::Template.new(key: 'a', subject: 'S', body: source), { name: 'Ann' })
    inlined = renderer.render(Spree::Emails::Template.new(key: 'a', subject: 'S', body: inline(source)), { name: 'Ann' })

    expect(inlined.html).to eq(original.html)
  end
end
