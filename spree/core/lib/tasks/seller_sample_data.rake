namespace :spree do
  namespace :sellers do
    desc 'Create a sample seller with a signed-in owner and a pending invitation, for trying the seller panel (development/test only)'
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

      # An offer on one of the marketplace's own products, so both the
      # seller's Offers page and the operator's review queue have something to
      # show (docs/plans/6.0-seller-master-catalog-listings.md). Skipped on a
      # store with no first-party catalog yet — this task runs before
      # spree:load_sample_data on a fresh install.
      master = store.products.active.for_seller(nil).first

      if master.nil?
        puts 'Offers:   skipped — no first-party product to list against yet (run spree:load_sample_data first).'
      else
        master.update!(open_to_sellers: true)
        location = seller.stock_locations.first

        offer = seller.variants.find_by(product: master, sku: 'SAMPLE-OFFER-1')

        # A value for every axis the product is sold by, taken from what it
        # already carries — an offer missing one lands in a different buy box
        # from the rows it is meant to compete with, which is exactly what the
        # seller endpoint refuses
        # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 7).
        axes = master.option_types.includes(:option_values).to_a
        options = axes.filter_map do |option_type|
          value = option_type.option_values.first
          { name: option_type.name, value: value.name } if value
        end

        if options.size != axes.size
          puts 'Offers:   skipped — a product option type carries no values to pick from.'
        elsif offer.nil?
          result = Spree.variant_create_workflow.call(
            product: master,
            attributes: {
              sku: 'SAMPLE-OFFER-1',
              seller_id: seller.id,
              status: 'draft',
              options: options,
              # Under the marketplace's own price, so the buy box has a real
              # decision to make once the offer is approved.
              prices: [{ currency: store.default_currency, amount: 9.5 }],
              stock_levels: location ? [{ stock_location_id: location.id, count_on_hand: 5 }] : []
            }
          )

          if result.success?
            offer = result.value
            # Left awaiting a decision rather than approved: the operator's
            # review queue is the thing that needs something in it.
            Spree.variant_propose_workflow.call(variant: offer, submitted_by: owner)
          else
            puts "Offers:   could not create the sample offer: #{result.value.errors.full_messages.to_sentence}"
          end
        else
          # An offer from an earlier run predates the option values above, and
          # a row missing an axis sits in the wrong buy box. Re-running the
          # task should leave the sample data correct, so reconcile it rather
          # than reporting a stale row as good.
          missing = axes.reject { |axis| offer.option_values.any? { |value| value.option_type_id == axis.id } }

          if missing.any?
            Spree.variant_update_workflow.call(variant: offer, attributes: { options: options })
            puts "Offers:   filled in #{missing.map(&:name).to_sentence} on the existing sample offer."
          end
        end

        puts "Offers:   #{offer.sku} on \"#{master.name}\" (#{offer.reload.status})" if offer
      end

      progress = Spree::Sellers::Requirements.new(seller.reload).progress

      puts "Seller:   #{seller.name} (#{seller.prefixed_id}, #{seller.status})"
      puts "Checklist: #{progress[:done]}/#{progress[:total]} done"
      puts "Sign in:  #{email}"
      puts "Pending:  #{seller.invitations.pending.pluck(:email).join(', ')}"
    end
  end
end
