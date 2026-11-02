namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Registers the PayPal webhook of every PayPal payment method and stores
      its id on the method, replacing the events of a webhook created by hand
      under the spree_paypal_checkout 0.x guide.

      Run once after upgrading to Spree 6.0. Without it, PayPal methods
      created before the upgrade have no webhook id and reject every
      delivery.

      Safe to run again.
    DESC
    task register_paypal_webhooks: :environment do
      registered = 0
      failed = []

      SpreePaypalCheckout::Gateway.find_each do |payment_method|
        # Locked as RegisterWebhookJob locks it, since a save can run one meanwhile.
        webhook = payment_method.with_lock { SpreePaypalCheckout::RegisterWebhook.new.call(payment_method: payment_method) }
        if webhook
          registered += 1
        else
          failed << { id: payment_method.id, error: 'it has no webhook URL; its store has no URL' }
        end
      rescue StandardError => e
        failed << { id: payment_method.id, error: e.message }
      end

      puts "Registered the webhook of #{registered} PayPal payment method(s)."
      next if failed.empty?

      failed.each { |failure| puts "  payment method #{failure[:id]}: #{failure[:error]}" }
      abort 'Some PayPal webhooks could not be registered. Re-run after resolving the errors above.'
    end
  end
end
