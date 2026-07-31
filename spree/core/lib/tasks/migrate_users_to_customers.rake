namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Moves an existing Devise-based user table onto the gem-owned auth models
      (Spree 6.0). Copies rows from the legacy customer table (default
      +spree_users+, override with SOURCE_USER_TABLE) into +spree_customers+ —
      preserving primary keys so the already-renamed +customer_id+ foreign keys
      still resolve, and mapping +encrypted_password+ into +password_digest+ —
      then re-points every polymorphic reference that named the old customer
      class (default +Spree::User+, override with SOURCE_USER_TYPE) to
      +Spree.customer_class+ — the +user_type+ columns plus +customer_type+ on
      customer-group memberships — and backfills +password_digest+ on
      +spree_admin_users+ from its legacy +encrypted_password+.

      Passwords survive with zero resets only when no Devise pepper was
      configured — Devise's +encrypted_password+ is a plain bcrypt digest, the
      exact format +has_secure_password+ reads. The task aborts if a pepper is
      detected; when Devise is absent (so a former pepper can't be introspected)
      it aborts until you confirm none was used with CONFIRM_NO_PEPPER=true.
      Source rows with a blank email, or whose email is already taken by a
      different customer, abort the task with their ids — reconcile them or pass
      SKIP_INVALID_ROWS=true to skip and continue. The legacy source table is
      left in place as a safety net.

      Idempotent — re-running skips rows already present in +spree_customers+.
      Batch size defaults to 1000 (override with BATCH_SIZE).
    DESC
    task migrate_users_to_customers: :environment do
      connection = ActiveRecord::Base.connection

      source_table = ENV.fetch('SOURCE_USER_TABLE', 'spree_users')
      old_type     = ENV.fetch('SOURCE_USER_TYPE', 'Spree::User')
      new_type     = Spree.customer_class.to_s
      batch_size   = (ENV['BATCH_SIZE'] || 1000).to_i

      unless connection.table_exists?(source_table)
        puts "  #{source_table} not found — nothing to migrate."
        next
      end

      # Peppered digests can't be verified by has_secure_password. Refuse rather
      # than silently produce accounts nobody can sign into. Once Devise is gone
      # a former pepper can't be introspected, so require an explicit all-clear.
      if defined?(Devise) && Devise.respond_to?(:pepper) && Devise.pepper.present?
        abort "  Devise.pepper is configured — bcrypt digests can't be copied into password_digest. " \
              "Use the custom-model path (keep the table, alias password_digest) or force password resets."
      elsif !defined?(Devise) && ENV['CONFIRM_NO_PEPPER'] != 'true'
        abort "  Devise isn't loaded, so a former Devise pepper can't be detected. A peppered digest " \
              "copied as-is can't be verified by has_secure_password — every migrated account would be " \
              "locked out silently. Re-run with CONFIRM_NO_PEPPER=true once you've confirmed the source " \
              "used no pepper, or use the custom-model path / force password resets."
      end

      customer_model = Spree.customer_class
      admin_model    = Spree.admin_user_class

      # Read the legacy table by name only — the Devise-era Spree::User /
      # Spree::LegacyUser models are gone in 6.0. Inherit from Spree.base_class
      # so the source shares the customer table's connection (the id-exclusion
      # subquery below spans both).
      source = Class.new(Spree.base_class) { self.table_name = source_table }

      # Copy only columns both tables share; map the digest column separately.
      direct_columns = customer_model.column_names & source.column_names
      copy_digest_from_encrypted = source.column_names.include?('encrypted_password') &&
                                    !direct_columns.include?('password_digest')
      has_marketing_column = customer_model.column_names.include?('accepts_email_marketing')

      # Preflight: catch rows we can't faithfully copy before writing anything, so
      # a bad row can't leave an already-renamed +customer_id+ foreign key pointing
      # at a customer that never migrated. Two kinds are rejected:
      #   1. Blank email — the target column is NOT NULL and uniquely indexed, so
      #      the row can't be inserted at all.
      #   2. Email already owned by a different customer — insert_all would abort
      #      the whole batch on the unique-email index.
      # Either kind aborts the task with the offending ids unless the operator
      # passes SKIP_INVALID_ROWS=true to skip them and continue.
      pending = source.where.not(id: customer_model.select(:id))
      blank_email_ids = pending.where("email IS NULL OR email = ''").pluck(:id)
      # Compare case-insensitively to match Spree::Customer's uniqueness
      # (case_sensitive: false) — emails are stored case-preserved, so a legacy
      # `Alice@` conflicting with an existing `alice@` must be caught here too.
      existing_emails = customer_model.where.not(email: [nil, '']).pluck(:email).map(&:downcase).to_set
      conflict_ids = pending.where("email IS NOT NULL AND email <> ''").pluck(:id, :email).
                             filter_map { |id, email| id if existing_emails.include?(email.downcase) }
      invalid_ids = (blank_email_ids + conflict_ids).uniq

      if invalid_ids.any? && ENV['SKIP_INVALID_ROWS'] != 'true'
        abort "  #{invalid_ids.size} source row(s) can't be migrated — " \
              "#{blank_email_ids.size} with a blank email#{blank_email_ids.any? ? " (ids: #{blank_email_ids.first(20).join(', ')})" : ''}, " \
              "#{conflict_ids.size} whose email is already taken by another customer#{conflict_ids.any? ? " (ids: #{conflict_ids.first(20).join(', ')})" : ''}. " \
              "Reconcile them, or re-run with SKIP_INVALID_ROWS=true to skip these and continue."
      end

      copied = 0

      pending.where.not(id: invalid_ids).in_batches(of: batch_size) do |relation|
        rows = relation.map do |record|
          attributes = record.attributes.slice(*direct_columns)
          attributes['password_digest'] = record[:encrypted_password] if copy_digest_from_encrypted
          # accepts_email_marketing is NOT NULL with no DB default — coalesce so a
          # legacy NULL (or a source table lacking the column) can't break the insert.
          attributes['accepts_email_marketing'] = false if has_marketing_column && attributes['accepts_email_marketing'].nil?
          attributes
        end

        next if rows.empty?

        customer_model.insert_all(rows)
        copied += rows.size
        print '.'
      end

      # insert_all writes explicit ids without advancing the Postgres sequence.
      connection.reset_pk_sequence!(customer_model.table_name) if connection.adapter_name.match?(/postgres/i)

      # Re-point polymorphic user references. Ids are preserved, so only the type
      # string changes; admin rows (Spree::AdminUser) stay put — that class name
      # is unchanged in 6.0. Customer-group memberships store the type in the
      # already-renamed +customer_type+ column; every other table still uses
      # +user_type+/+*_type+.
      repointed = {
        role_users:           Spree::RoleUser.where(user_type: old_type).update_all(user_type: new_type),
        refresh_tokens:       Spree::RefreshToken.where(user_type: old_type).update_all(user_type: new_type),
        user_identities:      Spree::UserIdentity.where(user_type: old_type).update_all(user_type: new_type),
        customer_group_users: Spree::CustomerGroupUser.where(customer_type: old_type).update_all(customer_type: new_type),
        api_keys_created_by:  Spree::ApiKey.where(created_by_type: old_type).update_all(created_by_type: new_type),
        api_keys_revoked_by:  Spree::ApiKey.where(revoked_by_type: old_type).update_all(revoked_by_type: new_type)
      }

      # Admins stay in spree_admin_users (in place) — backfill the digest from
      # the legacy column when present.
      admin_backfilled = 0
      if admin_model.column_names.include?('encrypted_password')
        admin_backfilled = admin_model.where(password_digest: [nil, '']).
                           where.not(encrypted_password: [nil, '']).
                           update_all('password_digest = encrypted_password')
      end

      puts
      puts "  Customers copied: #{copied} (skipped #{invalid_ids.size} invalid row(s): " \
           "#{blank_email_ids.size} blank-email, #{conflict_ids.size} email-conflict)."
      puts "  Admin password_digest backfilled: #{admin_backfilled}."
      puts "  Re-pointed #{old_type} -> #{new_type}: " \
           "role_users #{repointed[:role_users]}, refresh_tokens #{repointed[:refresh_tokens]}, " \
           "user_identities #{repointed[:user_identities]}, customer_group_users #{repointed[:customer_group_users]}, " \
           "api_keys #{repointed[:api_keys_created_by] + repointed[:api_keys_revoked_by]}."
      puts "  #{source_table} left in place — drop it once you've verified the migration."
    end
  end
end
