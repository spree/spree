namespace :spree do
  namespace :sellers do
    desc 'Create a sample seller with a signed-in owner and a pending invitation, for trying the seller panel'
    task sample_data: :environment do
      store = Spree::Store.default || Spree::Store.first
      abort 'No store found — run db:seed first.' if store.nil?

      email = ENV.fetch('SELLER_EMAIL', 'seller@example.com')
      password = ENV.fetch('SELLER_PASSWORD', 'spree123')

      seller = Spree::Seller.find_or_initialize_by(name: ENV.fetch('SELLER_NAME', 'Bright Sparks'), store: store)
      seller.save! if seller.new_record?
      seller.update!(status: 'approved') unless seller.approved?

      owner = Spree.admin_user_class.find_or_initialize_by(email: email)
      owner.password = password
      owner.first_name ||= 'Ada'
      owner.last_name ||= 'Lovelace'
      owner.save!
      seller.add_user(owner)

      # One outstanding offer, so the panel's pending-invitations card has
      # something to show without having to send an email first.
      invitee = ENV.fetch('SELLER_INVITEE', 'pending@example.com')
      unless seller.invitations.pending.exists?(email: invitee)
        seller.invitations.create!(email: invitee, role: seller.default_user_role, inviter: owner)
      end

      puts "Seller:   #{seller.name} (#{seller.prefixed_id}, #{seller.status})"
      puts "Sign in:  #{email} / #{password}"
      puts "Pending:  #{seller.invitations.pending.pluck(:email).join(', ')}"
    end
  end
end
