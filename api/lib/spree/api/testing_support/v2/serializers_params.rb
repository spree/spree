shared_context 'API v2 serializers params' do
  let(:store) { Spree::Store.default || create(:store, default: true) }
  let(:currency) { store.default_currency }
  let(:locale) { store.default_locale }

  let(:serializer_params) do
    {
      store: store,
      currency: currency,
      user: nil,
      locale: locale
    }
  end
end
