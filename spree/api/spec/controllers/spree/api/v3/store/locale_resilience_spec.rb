require 'spec_helper'

# A non-locale string in a store's locale settings made every request fail from
# a before_action, including the endpoints needed to undo it.
RSpec.describe Spree::Api::V3::Store::ChannelController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  # Spree::Current#locale asks the default market before the store column, so
  # the market is where a bad code actually reaches I18n.
  let(:market) { store.default_market }

  context 'when the resolved locale is not a loadable locale' do
    # update_column: the validation added alongside this spec now blocks the
    # normal write path, but upgrading installs still hold such rows.
    before { market.update_column(:default_locale, 'rubbish') }

    it 'still serves the request instead of raising' do
      expect { get :show }.not_to raise_error
      expect(response).to have_http_status(:ok)
    end

    it 'renders in the application default locale' do
      get :show

      expect(response).to have_http_status(:ok)
      expect(I18n.locale).to eq(I18n.default_locale)
    end
  end

  # known? accepts en-US and no spree_i18n bundle ships it, so validation alone
  # would still let a merchant configure an ordinary locale and go down.
  context 'when the resolved locale is valid but ships no UI translations' do
    before do
      expect(I18n.available_locales.map(&:to_s)).not_to include('en-US')
      market.update_column(:default_locale, 'en-US')
    end

    it 'serves the request rather than failing on the missing bundle' do
      get :show

      expect(response).to have_http_status(:ok)
    end
  end
end
