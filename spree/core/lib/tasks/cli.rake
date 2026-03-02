namespace :spree do
  namespace :cli do
    desc 'Ensure a default publishable API key exists and print its token'
    task ensure_api_key: :environment do
      store = Spree::Store.default
      key = store.api_keys.active.publishable.first ||
            store.api_keys.create!(name: 'Default', key_type: 'publishable')
      print key.plaintext_token
    end

    desc 'Create an API key'
    task create_api_key: :environment do
      name = ENV.fetch('NAME')
      key_type = ENV.fetch('KEY_TYPE')
      store = Spree::Store.default
      key = store.api_keys.create!(name: name, key_type: key_type)
      print key.plaintext_token
    end

    desc 'List API keys (pipe-delimited)'
    task list_api_keys: :environment do
      Spree::Store.default.api_keys.order(created_at: :desc).each do |k|
        status = k.revoked_at ? 'revoked' : 'active'
        token = k.secret? ? k.token_prefix : k.token
        puts [k.prefixed_id, k.name, k.key_type, token, k.created_at.strftime('%Y-%m-%d %H:%M'), status].join('|')
      end
    end

    desc 'Revoke an API key by prefixed ID'
    task revoke_api_key: :environment do
      id = ENV.fetch('ID')
      key = Spree::Store.default.api_keys.find_by_prefix_id!(id)
      key.revoke!
      print key.name
    end

    desc 'Create an admin user'
    task create_admin: :environment do
      email = ENV.fetch('EMAIL')
      password = ENV.fetch('PASSWORD')
      admin = Spree.admin_user_class.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
      admin.add_role('admin', Spree::Store.default)
      print admin.email
    end
  end
end
