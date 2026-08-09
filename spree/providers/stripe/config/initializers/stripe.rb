Stripe.log_level = ENV.fetch('STRIPE_LOG_LEVEL', 'info')
Stripe.api_version = '2023-10-16'
Stripe.set_app_info('Spree Stripe', version: Spree.version, url: 'https://spreecommerce.org')
