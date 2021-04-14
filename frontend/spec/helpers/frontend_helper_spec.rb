require 'spec_helper'

module Spree
  describe FrontendHelper, type: :helper do
    # Regression test for #2034
    context 'flash_message' do
      let(:flash) { { 'notice' => 'ok', 'error' => 'foo', 'warning' => 'bar' } }

      it 'outputs all flash content' do
        messages = flash_messages
        expect(messages).to have_css ".alert-#{class_for('notice')}", text: 'ok'
        expect(messages).to have_css ".alert-#{class_for('error')}", text: 'foo'
        expect(messages).to have_css ".alert-#{class_for('warning')}", text: 'bar'
      end

      it 'outputs flash content except one key' do
        messages = flash_messages(excluded_types: [:warning])
        expect(messages).to have_css ".alert-#{class_for('notice')}", text: 'ok'
        expect(messages).to have_css ".alert-#{class_for('error')}", text: 'foo'
        expect(messages).not_to have_css ".alert-#{class_for('warning')}", text: 'bar'
      end

      it 'outputs flash content except some keys' do
        messages = flash_messages(excluded_types: [:error, :warning])
        expect(messages).to have_css ".alert-#{class_for('notice')}", text: 'ok'
        expect(messages).not_to have_css ".alert-#{class_for('error')}", text: 'foo'
        expect(messages).not_to have_css ".alert-#{class_for('warning')}", text: 'bar'
        expect(messages).to eq('<div class="alert alert-success mb-0"><button class="close" data-dismiss="alert" data-hidden="true">&times;</button><span>ok</span></div>')
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
        expect(output).not_to include('1. Address')
      end

      it 'has option to include numbers' do
        output = checkout_progress(numbers: true)
        expect(output).to include('1. Address')
      end
    end

    describe '#country_flag_icon' do
      it { expect(country_flag_icon('US')).to eq('<span class="flag-icon flag-icon-us"></span>') }
      it { expect { country_flag_icon(nil) }.not_to raise_error }
    end
  end
end
