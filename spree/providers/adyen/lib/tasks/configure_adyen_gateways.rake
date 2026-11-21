namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Moves each Adyen payment method's previous HMAC key out of its metadata,
      which the Admin API returns, into a secret preference, then configures
      the method: client key, allowed origins and a webhook on the 6.0 URL. A
      webhook 5.x left on /adyen/webhooks is moved in place.

      Run once after upgrading to Spree 6.0. Safe to run again.
    DESC
    task configure_adyen_gateways: :environment do
      configured = 0
      failed = []

      SpreeAdyen::Gateway.find_each do |payment_method|
        # Locked as ConfigureJob locks it, since a save can run one meanwhile.
        payment_method.with_lock do
          previous_key = payment_method.metadata['previous_hmac_key']
          if payment_method.metadata.key?('previous_hmac_key')
            payment_method.preferred_previous_hmac_key = previous_key if previous_key.present? && payment_method.preferred_previous_hmac_key.blank?
            payment_method.metadata = payment_method.metadata.except('previous_hmac_key')
            payment_method.save!
          end

          SpreeAdyen::Configure.call(payment_method)
        end
        configured += 1
      rescue StandardError => e
        failed << { id: payment_method.id, error: e.message }
      end

      puts "Configured #{configured} Adyen payment method(s)."
      next if failed.empty?

      failed.each { |failure| puts "  payment method #{failure[:id]}: #{failure[:error]}" }
      abort 'Some Adyen payment methods could not be configured. Re-run after resolving the errors above.'
    end
  end
end
