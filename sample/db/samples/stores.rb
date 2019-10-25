spree_store = Spree::Store.find_by!(code: 'spree')
spree_store.default_currency = 'USD'
spree_store.url = Rails.application.routes.default_url_options[:host]
spree_store.save!
