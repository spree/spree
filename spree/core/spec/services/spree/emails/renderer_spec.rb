require 'spec_helper'

describe Spree::Emails::Renderer do
  subject(:renderer) { described_class.new(resolver: resolver, store: store) }

  let(:store) { @default_store }
  let(:views) { Pathname.new(Dir.mktmpdir) }
  let(:resolver) do
    Spree::Emails::TemplateResolver.new([views, Spree::Core::Engine.root.join('app/views')])
  end

  after { FileUtils.remove_entry(views) }

  def write(key, source)
    path = views.join(key)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, source)
  end

  def render(body, assigns = {}, subject: 'Test email')
    write('spree/test_mailer/test_email.liquid', "---\nsubject: \"#{subject}\"\n---\n#{body}")
    renderer.render(resolver.find('spree/test_mailer/test_email'), assigns)
  end

  def section(content)
    "<mj-section><mj-column><mj-text>#{content}</mj-text></mj-column></mj-section>"
  end

  it 'renders the subject from the front matter and the body inside the layout' do
    email = render(section('Body for {{ name }}'), { name: 'Ann' }, subject: 'Hello {{ name }}')

    expect(email.subject).to eq('Hello Ann')
    expect(email.html).to include('Body for Ann')
    expect(email.html).to include(store.name)
    expect(email.html).not_to include('<mj-', '{{', '{%')
  end

  it 'generates the plain-text part from the HTML, keeping links' do
    email = render(section('<a href="https://example.com/reset">Reset</a>'), { name: 'Ann' })

    expect(email.text).to include('Reset (https://example.com/reset)')
    expect(email.text).not_to include('<')
  end

  it 'uses a hand-written text part when the template has one' do
    write('spree/test_mailer/test_email.text.liquid', 'Plain {{ name }} & co')

    expect(render(section('x'), { name: 'Ann' }).text).to eq('Plain Ann & co')
  end

  describe 'escaping' do
    let(:payload) { '<a href="https://evil.test">Click to verify</a>' }

    it 'escapes every output, including values assigned first' do
      email = render(section('{{ name }} {% assign copy = name %}{{ copy }}'), { name: payload })

      expect(email.html).not_to include('<a href="https://evil.test">')
      expect(email.html.scan('&lt;a href=').size).to eq(2)
    end

    it 'escapes captured text once' do
      email = render(section('{% capture greeting %}Hi {{ name }}{% endcapture %}{{ greeting }}'), { name: "O'Brien & Co" })

      expect(email.html).to include('Hi O&#39;Brien &amp; Co')
    end

    it 'keeps captured text escaped once after trimming it' do
      email = render(section('{% capture greeting %} Hi {{ name }} {% endcapture %}{{ greeting | strip }}'), { name: 'Smith & Co' })

      expect(email.html).to include('Hi Smith &amp; Co')
    end

    it 'escapes captured text once through any filter, and escapes the filter arguments' do
      email = render(section("{% capture greeting %}Hi {{ name }}{% endcapture %}{{ greeting | append: ' & <b>more</b>' }}"), { name: 'Smith & Co' })

      expect(email.html).to include('Hi Smith &amp; Co &amp; &lt;b&gt;more&lt;/b&gt;')
    end

    it 'never trusts captured text a filter decoded into markup' do
      email = render(section('{% capture note %}{{ text }}{% endcapture %}{{ note | url_decode }}'), { text: '%3Cb%3Ebold%3C%2Fb%3E' })

      expect(email.html).to include('&lt;b&gt;bold&lt;/b&gt;')
      expect(email.html).not_to include('<b>bold</b>')
    end

    it 'escapes what cycle writes' do
      email = render(section("{% cycle name, 'x' %}"), { name: payload })

      expect(email.html).not_to include('<a href="https://evil.test">')
    end

    it 'escapes what a partial outputs' do
      write('spree/shared/_greeting.liquid', '{{ who }}')

      email = render(section("{% render 'spree/shared/greeting', who: name %}"), { name: payload })

      expect(email.html).not_to include('<a href="https://evil.test">')
      expect(email.html).to include('&lt;a href=')
    end

    it 'does not escape a value marked raw' do
      expect(render(section('{{ html | raw }}'), { html: '<strong>bold</strong>' }).html).to include('<strong>bold</strong>')
    end

    it 'keeps the subject as plain text' do
      expect(render(section('x'), { name: 'Tom & Jerry' }, subject: 'Hello {{ name }}').subject).to eq('Hello Tom & Jerry')
    end

    it 'escapes interpolated translations once' do
      email = render(section("{{ 'admin_user_mailer.password_reset_email.greeting' | t: name: name }}"), { name: 'Ann <b>' })

      expect(email.html).to include('Ann &lt;b&gt;')
      expect(email.text).to include('Ann <b>')
    end
  end

  it 'raises on a misspelled field, so a typo fails a spec rather than rendering blank' do
    expect { render(section('{{ order.nubmer }}'), { order: { number: 'R1' } }) }.to raise_error(Liquid::UndefinedVariable)
  end

  it 'lets a partial take optional arguments' do
    write('spree/shared/_optional.liquid', '[{{ maybe }}]')

    expect(render(section("{% render 'spree/shared/optional' %}"), { name: 'Ann' }).html).to include('[]')
  end

  it 'refuses a partial name that leaves the view paths' do
    expect { render(section("{% render '../../etc/passwd' %}")) }.to raise_error(Liquid::FileSystemError)
  end

  it 'fails a runaway template instead of rendering it' do
    expect { render(section('{% for i in (1..10000000) %}{{ i }}{% endfor %}')) }.to raise_error(Liquid::MemoryError)
  end

  describe 'filters' do
    it 'formats money in the email currency' do
      eur = described_class.new(resolver: resolver, store: store, currency: 'EUR')
      write('spree/test_mailer/test_email.liquid', "---\nsubject: \"{{ amount | money }} {{ amount | money_with_currency }}\"\n---\n#{section('x')}")

      expect(eur.render(resolver.find('spree/test_mailer/test_email'), amount: '10.5').subject).to eq('€10.50 €10.50 EUR')
    end

    it "formats dates in the store's time zone" do
      allow(store).to receive(:preferred_timezone).and_return('Pacific/Auckland')

      email = render(section('x'), { at: '2026-01-01T20:00:00Z' }, subject: "{{ at | date: '%Y-%m-%d %H:%M' }} {{ at | date: 'long' }}")

      expect(email.subject).to eq('2026-01-02 09:00 January 02, 2026')
    end

    it 'formats a date with no time of day as that day' do
      allow(store).to receive(:preferred_timezone).and_return('Pacific/Honolulu')

      expect(render(section('x'), { on: '2026-12-31' }, subject: "{{ on | date: 'long' }}").subject).to eq('December 31, 2026')
    end
  end
end
