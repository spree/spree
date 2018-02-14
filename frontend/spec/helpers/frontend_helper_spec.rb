require 'spec_helper'

module Spree
  describe FrontendHelper, type: :helper do
    # Regression test for #2034
    context 'flash_message' do
      let(:flash) { { 'notice' => 'ok', 'foo' => 'foo', 'bar' => 'bar' } }

      it 'outputs all flash content' do
        flash_messages
        html = Nokogiri::HTML(helper.output_buffer)
        expect(html.css('.alert-notice').text).to eq('ok')
        expect(html.css('.alert-foo').text).to eq('foo')
        expect(html.css('.alert-bar').text).to eq('bar')
      end

      it 'outputs flash content except one key' do
        flash_messages(ignore_types: :bar)
        html = Nokogiri::HTML(helper.output_buffer)
        expect(html.css('.alert-notice').text).to eq('ok')
        expect(html.css('.alert-foo').text).to eq('foo')
        expect(html.css('.alert-bar').text).to be_empty
      end

      it 'outputs flash content except some keys' do
        flash_messages(ignore_types: [:foo, :bar])
        html = Nokogiri::HTML(helper.output_buffer)
        expect(html.css('.alert-notice').text).to eq('ok')
        expect(html.css('.alert-foo').text).to be_empty
        expect(html.css('.alert-bar').text).to be_empty
        expect(helper.output_buffer).to eq('<div class="alert alert-notice">ok</div>')
      end
    end

    # Regression test for #2759
    it 'nested_taxons_path works with a Taxon object' do
      taxon = create(:taxon, name: 'iphone')
      expect(spree.nested_taxons_path(taxon)).to eq("/t/#{taxon.parent.permalink}/#{taxon.name}")
    end

    context '#checkout_progress' do
      before do
        @order = create(:order, state: 'address')
      end

      it 'does not include numbers by default' do
        output = checkout_progress
        expect(output).not_to include('1.')
      end

      it 'has option to include numbers' do
        output = checkout_progress(numbers: true)
        expect(output).to include('1.')
      end
    end
  end
end
