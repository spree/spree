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

    describe '#product_description' do
      let(:store) { create(:store) }
      let(:product) { create(:product, stores: [store]) }

      context 'when configuration is set to sanitize output' do
        it 'renders a product description with automatic paragraph breaks' do
          product.description = %Q{
THIS IS THE BEST PRODUCT EVER!

"IT CHANGED MY LIFE" - Sue, MD}

          description = product_description(product)
          expect(description.strip).to eq(%Q{<p>\nTHIS IS THE BEST PRODUCT EVER!</p>"IT CHANGED MY LIFE" - Sue, MD})
        end

        it 'renders a product description without any formatting based on configuration' do
          initial_description = %Q{
              <p>hello world</p>

              <p>tihs is completely awesome and it works</p>

              <p>why so many spaces in the code. and why some more formatting afterwards?</p>
          }

          product.description = initial_description

          Spree::Frontend::Config[:show_raw_product_description] = true
          description = product_description(product)
          expect(description).to eq(initial_description)
        end

        context 'renders a product description default description incase description is blank' do
          before { product.description = '' }

          it { expect(product_description(product)).to eq(Spree.t(:product_has_no_description)) }
        end
      end
    end
  end
end
