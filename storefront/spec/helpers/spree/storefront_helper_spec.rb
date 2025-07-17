require 'spec_helper'

describe Spree::StorefrontHelper, type: :helper do
  describe '#show_account_pane?' do
    let(:user) { create(:user) }

    before do
      allow(helper).to receive(:try_spree_current_user).and_return(current_user)
      allow(helper).to receive(:spree_login_path).and_return('/login')
      allow(helper).to receive(:spree_signup_path).and_return('/signup')
      allow(helper).to receive(:spree_forgot_password_path).and_return('/forgot-password')
      allow(helper).to receive(:canonical_path).and_return(current_path)
    end

    context 'when user is logged in' do
      let(:current_user) { user }
      let(:current_path) { '/some-path' }

      it 'returns false' do
        expect(helper.show_account_pane?).to be false
      end
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      context 'when current path is login path' do
        let(:current_path) { '/login' }

        it 'returns false' do
          expect(helper.show_account_pane?).to be false
        end

        context 'with query parameters' do
          before do
            allow(helper).to receive(:spree_login_path).and_return('/login?redirect=/products')
          end

          it 'returns false when current path has different query params' do
            allow(helper).to receive(:canonical_path).and_return('/login?return_to=/cart')
            expect(helper.show_account_pane?).to be false
          end

          it 'returns false when current path has no query params' do
            allow(helper).to receive(:canonical_path).and_return('/login')
            expect(helper.show_account_pane?).to be false
          end
        end
      end

      context 'when current path is signup path' do
        let(:current_path) { '/signup' }

        it 'returns false' do
          expect(helper.show_account_pane?).to be false
        end

        context 'with query parameters' do
          before do
            allow(helper).to receive(:spree_signup_path).and_return('/signup?redirect=/products')
          end

          it 'returns false when current path has different query params' do
            allow(helper).to receive(:canonical_path).and_return('/signup?return_to=/cart')
            expect(helper.show_account_pane?).to be false
          end
        end
      end

      context 'when current path is forgot password path' do
        let(:current_path) { '/forgot-password' }

        it 'returns false' do
          expect(helper.show_account_pane?).to be false
        end

        context 'with query parameters' do
          before do
            allow(helper).to receive(:spree_forgot_password_path).and_return('/forgot-password?redirect=/products')
          end

          it 'returns false when current path has different query params' do
            allow(helper).to receive(:canonical_path).and_return('/forgot-password?return_to=/cart')
            expect(helper.show_account_pane?).to be false
          end
        end
      end

      context 'when current path is different from authentication paths' do
        let(:current_path) { '/products' }

        it 'returns true' do
          expect(helper.show_account_pane?).to be true
        end
      end
    end
  end

  describe '#svg_country_icon' do
    it 'returns correct flag class for uk language code' do
      expect(svg_country_icon(['uk', :uk].sample)).to include('fi fi-ua')
    end

    it 'returns correct flag class for en language code' do
      expect(svg_country_icon(['en', :en].sample)).to include('fi fi-us')
    end

    it 'returns correct flag class for ja language code' do
      expect(svg_country_icon(['ja', :ja].sample)).to include('fi fi-jp')
    end

    it 'returns correct flag class for unknown language code' do
      expect(svg_country_icon('fr')).to include('fi fi-fr')
    end
  end
end
