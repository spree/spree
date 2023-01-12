require 'spec_helper'
require 'pry'

module Spree
  describe Export::GoogleRss do
    subject { described_class.new }

    let(:store) { create(:store) }
    let(:setting) { create(:google_feed_setting, store: store) }
    let(:product) { create(:product, stores: [store]) }
    let!(:variant) { create(:with_image_variant, product: product) }
    let(:result) { subject.call(setting) }

    context 'store header is generated correctly' do
      before do
        allow(subject).to receive(:store).and_return(store)
      end

      it 'store name' do
        expect(result).to include("<title>#{store.name}</title>").once
      end

      it 'store url' do
        expect(result).to include("<link>#{store.url}</link>").once
      end

      it 'store description' do
        expect(result).to include("<description>#{store.meta_description}</description>").once
      end
    end

    context 'item attributes are generated correctly' do
      before do
        allow(subject).to receive(:store).and_return(store)
      end

      context 'required information' do
        it 'id' do
          expect(result).to include("<g:id>#{variant.id}</g:id>").once
        end

        it 'title' do
          expect(result).to include("<g:title>#{product.name} - #{variant.option_values.first.name}</g:title>").once
        end

        it 'description' do
          expect(result).to include("<g:description>#{product.description}</g:description>").once
        end

        it 'link' do
          expect(result).to include("<g:link>#{store.url}/#{product.slug}</g:link>").once
        end

        it 'image link' do
          expect(result).to include("<g:image_link>#{variant.images.first.plp_url}</g:image_link>").once
        end

        it 'price' do
          expect(result).to include("<g:price>#{variant.price} #{variant.cost_currency}</g:price>").once
        end

        context 'availability date is in the past' do
          it 'product is in stock' do
            expect(result).to include('<g:availability>in stock</g:availability>')
          end
        end

        context 'availability date is in the future' do
          let(:product) { create(:product, stores: [store], available_on: 1.year.from_now) }

          it 'product is on backorder' do
            expect(result).to include('<g:availability>backorder</g:availability>')
          end
        end

        context 'availability date is nil' do
          let(:product) { create(:product, stores: [store], available_on: nil) }

          it 'product is out of stock' do
            expect(result).to include('<g:availability>out of stock</g:availability>')
          end
        end
      end
    end
  end
end
