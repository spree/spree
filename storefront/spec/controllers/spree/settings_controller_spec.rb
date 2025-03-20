require 'spec_helper'

describe Spree::SettingsController, type: :controller do
  let(:supported_currencies) { 'USD,EUR,PLN' }
  let(:supported_locales) { 'en,fr,es' }
  let(:store) { create(:store, supported_locales: supported_locales, supported_currencies: supported_currencies) }
  let(:user) { create(:user) }

  before do
    class_double('SpreeI18n').
      as_stubbed_const(transfer_nested_constants: true)
    class_double('SpreeI18n::Locale', all: [:en, :fr, :es]).as_stubbed_const(transfer_nested_constants: true)
    Rails.application.reload_routes!

    allow(controller).to receive(:current_store).and_return(store)
  end

  describe 'PUT #update' do
    describe 'currencies' do
      subject(:set_currency) { put :update, params: params }

      let(:params) { { switch_to_currency: 'EUR' } }
      let(:order) { create(:order_with_totals, currency: 'USD', store: store) }

      before do
        allow(controller).to receive(:current_order).and_return(order)
      end

      context 'when switching to a supported currency' do
        let(:supported_currencies) { 'USD,EUR,PLN' }

        it 'sets the new currency' do
          set_currency

          expect(response.status).to eq(302)

          expect(session[:currency]).to eq('EUR')
          expect(order.reload.currency).to eq('EUR')
        end
      end

      context 'when switching to an unsupported currency' do
        let(:supported_currencies) { 'USD,PLN' }

        it 'skips setting a new currency' do
          set_currency

          expect(response.status).to eq(302)

          expect(session[:currency]).to be_nil
          expect(order.reload.currency).to eq('USD')
        end
      end

      context 'without params' do
        let(:params) { nil }
        let(:supported_currencies) { 'USD,EUR,PLN' }

        it 'skips setting a new currency' do
          set_currency

          expect(response.status).to eq(302)

          expect(session[:currency]).to be_nil
          expect(order.reload.currency).to eq('USD')
        end
      end

      context 'without the current order' do
        let(:order) { nil }
        let(:supported_currencies) { 'USD,EUR,PLN' }

        it 'sets the currency for the storefront only' do
          set_currency

          expect(response.status).to eq(302)
          expect(session[:currency]).to eq('EUR')
        end
      end
    end

    describe 'locales' do
      context 'when user is logged in' do
        before do
          allow(controller).to receive(:try_spree_current_user).and_return(user)
        end

        context 'with a valid locale' do
          it 'updates the user locale' do
            put :update, params: { switch_to_locale: 'fr' }
            expect(user.reload.selected_locale).to eq('fr')
          end

          context 'without referer' do
            subject { put :update, params: { switch_to_locale: switch_to_locale } }

            let(:switch_to_locale) { 'fr' }

            it 'redirects to root path with new locale' do
              subject
              expect(response).to redirect_to(spree.root_path(locale: 'fr'))
            end

            context 'when switching back to the store default locale' do
              let(:switch_to_locale) { 'en' }

              it 'redirects to the product page with the correct slug in the default locale' do
                subject
                expect(response).to redirect_to('/')
              end
            end
          end

          context 'with referer' do
            before do
              request.env['HTTP_REFERER'] = spree.products_path
            end

            it 'redirects to the previous page with new locale' do
              put :update, params: { switch_to_locale: 'fr' }
              expect(response).to redirect_to(spree.products_path(locale: 'fr'))
            end

            context 'when referer is a product page' do
              let!(:product) { create(:product, name: 'Test Product', stores: [store]) }

              before do
                Mobility.with_locale(:fr) { product.update!(name: 'Produit Test', slug: 'produit-test') }
                Mobility.with_locale(:es) { product.update!(name: 'Producto de Prueba', slug: 'producto-de-prueba') }

                request.env['HTTP_REFERER'] = spree.product_path(product)
              end

              it 'redirects to the product page with the correct slug in the new locale' do
                put :update, params: { switch_to_locale: 'fr' }
                expect(response).to redirect_to('/fr/products/produit-test')
              end

              context 'when switching back to the store default locale' do
                before do
                  request.env['HTTP_REFERER'] = spree.product_path(product, locale: 'fr')
                end

                it 'redirects to the product page with the correct slug in the default locale' do
                  put :update, params: { switch_to_locale: 'en' }
                  expect(response).to redirect_to('/products/test-product')
                end
              end
            end

            context 'when referer is a taxon page' do
              let!(:taxon) { create(:taxon, name: 'Category', taxonomy: store.taxonomies.first) }

              before do
                Mobility.with_locale(:fr) { taxon.update!(name: 'Catégorie', permalink: 'categorie') }
                Mobility.with_locale(:es) { taxon.update!(name: 'Categoría', permalink: 'categoria') }

                request.env['HTTP_REFERER'] = spree.nested_taxons_path(taxon.permalink)
              end

              it 'redirects to the taxon page with the correct permalink in the new locale' do
                put :update, params: { switch_to_locale: 'fr' }
                expect(response).to redirect_to("/fr/t/#{taxon.parent.slug}/categorie")
              end

              context 'when switching back to the store default locale' do
                before do
                  request.env['HTTP_REFERER'] = spree.nested_taxons_path(taxon.permalink, locale: 'fr')
                end

                it 'redirects to the taxon page with the correct permalink in the default locale' do
                  put :update, params: { switch_to_locale: 'en' }
                  expect(response).to redirect_to("/t/#{taxon.parent.slug}/category")
                end
              end
            end

            context 'when referer is another controller' do
              before do
                request.env['HTTP_REFERER'] = spree.cart_path
              end

              it 'redirects to the same page with new locale' do
                put :update, params: { switch_to_locale: 'fr' }
                expect(response).to redirect_to(spree.cart_path(locale: 'fr'))
              end
            end
          end
        end

        context 'with an invalid locale' do
          it 'redirects to root path without changing locale' do
            put :update, params: { switch_to_locale: 'invalid' }
            expect(response).to redirect_to(spree.root_path)
            expect(user.reload.selected_locale).not_to eq('invalid')
          end
        end
      end

      context 'when user is not logged in' do
        before do
          allow(controller).to receive(:try_spree_current_user).and_return(nil)
        end

        it 'does not attempt to update user locale' do
          put :update, params: { switch_to_locale: 'fr' }
          expect(response).to redirect_to(spree.root_path(locale: 'fr'))
        end

        context 'with referer' do
          before do
            request.env['HTTP_REFERER'] = spree.products_path
          end

          it 'redirects to the previous page with new locale' do
            put :update, params: { switch_to_locale: 'fr' }
            expect(response).to redirect_to(spree.products_path(locale: 'fr'))
          end
        end

        context 'with an invalid locale' do
          it 'redirects to root path without changing locale' do
            put :update, params: { switch_to_locale: 'invalid' }
            expect(response).to redirect_to(spree.root_path)
          end
        end
      end
    end
  end
end
