namespace :spree do
  namespace :setup do
    desc 'Print the one-time first-run setup URL (only while no admin user exists); ROTATE=1 issues a fresh token first'
    task token: :environment do
      if Spree.admin_user_class.blank? || Spree.admin_user_class.count.positive?
        abort 'An admin account already exists — first-run setup is closed. Use invitations to add more admins.'
      end

      store = Spree::Store.default
      abort 'No store yet — run `bin/rails db:seed` first.' if store.nil?

      store.regenerate_setup_token if store.setup_token.blank? || ENV['ROTATE'] == '1'

      puts 'Open this link (with your app running) to create the first admin account:'
      puts "  #{store.setup_url}"
    end
  end
end
