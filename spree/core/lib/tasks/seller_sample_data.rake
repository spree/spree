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

      seller = Spree::Seller.find_or_initialize_by(name: ENV.fetch('SELLER_NAME', 'Bright Sparks'), store: store)
      seller.status = 'approved' if seller.new_record?
      seller.save! if seller.new_record?

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

      puts "Seller:   #{seller.name} (#{seller.prefixed_id}, #{seller.status})"
      puts "Sign in:  #{email}"
      puts "Pending:  #{seller.invitations.pending.pluck(:email).join(', ')}"
    end
  end
end
