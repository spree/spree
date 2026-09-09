namespace :spree do
  namespace :sellers do
    desc 'Create a sample seller with an owner, a pending invitation and a fund ledger, for trying the seller panel (development/test only)'
    task sample_data: :environment do
      # Refused outside development and test on purpose. This task writes a
      # known password, and `find_or_initialize_by(email:)` can land on a real
      # account — resetting a live user's credentials from a sample-data task
      # is not a mistake worth leaving available.
      unless Rails.env.development? || Rails.env.test?
        abort "spree:sellers:sample_data is for development and test only (RAILS_ENV=#{Rails.env})."
      end

      store = Spree::Store.default || Spree::Store.first
      abort 'No store found — run db:seed first.' if store.nil?

      email = ENV.fetch('SELLER_EMAIL', 'seller@example.com')
      password = ENV.fetch('SELLER_PASSWORD', 'spree123')

      seller_name = ENV.fetch('SELLER_NAME', 'Bright Sparks')
      seller = Spree::Seller.find_by(name: seller_name, store: store)

      # Through the workflow, so the sample seller gets the stock location a
      # real one does — without it their returns have nowhere to go and the
      # checklist can never be finished.
      if seller.nil?
        result = Spree.seller_create_workflow.call(
          store: store, attributes: { name: seller_name, status: 'approved' }
        )
        abort "Could not create the sample seller: #{result.value.errors.full_messages.to_sentence}" unless result.success?

        seller = result.value
      end

      owner = Spree.admin_user_class.find_by(email: email)

      # An existing account keeps its own password. Re-running the task then
      # tells you to use the credentials you already have, rather than silently
      # changing them underneath you.
      if owner
        puts "Reusing existing user #{email} — password unchanged."
      else
        owner = Spree.admin_user_class.create!(
          email: email, password: password, first_name: 'Ada', last_name: 'Lovelace'
        )
      end

      seller.add_user(owner)

      # One outstanding offer, so the panel's pending-invitations card has
      # something to show without having to send an email first.
      invitee = ENV.fetch('SELLER_INVITEE', 'pending@example.com')
      unless seller.invitations.pending.exists?(email: invitee)
        seller.invitations.create!(email: invitee, role: seller.default_user_role, inviter: owner)
      end

      # A checklist to work through, so the panel's onboarding page and its
      # nav counter have something to show. Skipped when the marketplace
      # already defines its own.
      if store.seller_requirements.none?
        Spree::SellerRequirements::AcceptTerms.create!(store: store, position: 1, active: true, required: true)
        Spree::SellerRequirements::BillingAddress.create!(store: store, position: 2, active: true, required: true)
        Spree::SellerRequirements::ReturnsAddress.create!(store: store, position: 3, active: true, required: true)
        Spree::SellerRequirements::Attestation.create!(
          store: store, position: 4, active: true, required: true,
          name: 'Confirm you can ship within two working days'
        )
        Spree::SellerRequirements::OperatorReview.create!(
          store: store, position: 5, active: true, required: false,
          name: 'Marketplace background check'
        )
      end

      # A fund ledger to read: a settled payout with the sales it covered, one
      # still owed, and a sale not yet swept into either. Written directly
      # rather than through fulfilment and the payout sweep — reaching those
      # would mean placing and shipping real orders, which is a different
      # task's job, and the screens under test read these rows either way.
      provider = Spree::PayoutProvider::System.provider_key
      currency = store.default_currency

      if seller.seller_transfers.none?
        # Each earning hangs off an order, because that is what a seller
        # clicks through to from their ledger.
        sample_orders = 5.times.map do |index|
          Spree::Order.create!(
            store: store, seller: seller, currency: currency,
            email: "sample-buyer-#{index + 1}@example.com",
            status: 'placed', completed_at: (index + 1).weeks.ago,
            total: 100 + (index * 25), item_total: 100 + (index * 25)
          )
        end

        settled = seller.seller_payouts.create!(
          store: store, amount: 0, currency: currency, provider: provider, status: 'completed',
          reference: 'BACS-SAMPLE-001',
          period_start: 6.weeks.ago, period_end: 4.weeks.ago
        )
        owed = seller.seller_payouts.create!(
          store: store, amount: 0, currency: currency, provider: provider, status: 'pending',
          period_start: 3.weeks.ago, period_end: 1.week.ago
        )

        # Two settled, two owed, one still unswept — so the balance is a real
        # subtraction rather than a single number, and the payouts queue has
        # both a completed row and one to mark paid.
        [[settled, 0], [settled, 1], [owed, 2], [owed, 3], [nil, 4]].each do |payout, index|
          order = sample_orders[index]
          seller.seller_transfers.create!(
            store: store, order: order, payout: payout,
            amount: order.total * 0.85, currency: currency,
            kind: 'earning', provider: provider, status: 'completed',
            created_at: order.completed_at
          )
        end

        # A refund on the newest settled sale, so the reversal row and the
        # negative amount both appear on the earnings screens.
        original = seller.seller_transfers.earnings.order(:created_at).last
        seller.seller_transfers.create!(
          store: store, order: original.order, reversed_from: original,
          amount: -(original.amount * 0.5), currency: currency,
          kind: 'refund_reversal', provider: provider, status: 'completed'
        )

        # Each settlement is worth exactly what it claimed.
        [settled, owed].each { |payout| payout.update!(amount: payout.transfers.sum(:amount)) }
      end

      progress = Spree::Sellers::Requirements.new(seller.reload).progress
      balances = seller.balances

      puts "Seller:   #{seller.name} (#{seller.prefixed_id}, #{seller.status})"
      puts "Checklist: #{progress[:done]}/#{progress[:total]} done"
      puts "Sign in:  #{email}"
      puts "Pending:  #{seller.invitations.pending.pluck(:email).join(', ')}"
      puts "Ledger:   #{seller.seller_transfers.count} earning(s), #{seller.seller_payouts.count} payout(s)"
      balances.each do |balance|
        puts "Balance:  #{balance.display_balance} owed (#{balance.display_earned} earned, #{balance.display_paid} paid)"
      end
    end
  end
end
