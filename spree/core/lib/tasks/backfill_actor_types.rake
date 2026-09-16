namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Names the admin user class on every "who did this" row written before
      those associations became polymorphic (Spree 6.0). Rows with an actor id
      and no actor type could only ever have pointed at an admin user, so the
      type is filled in and the transitional reader stops being needed.

      Runs over whatever each model declares with `acted_by`, so the 6.1
      conversion of the remaining associations reuses this task unchanged.
      Idempotent: a row that already carries a type is skipped.
    DESC
    task backfill_actor_types: :environment do
      # The registry fills as models load, so a development console (where
      # eager loading is off) would otherwise back-fill only the handful of
      # models something happened to reference.
      Rails.application.eager_load!

      actor_type = Spree.admin_user_class.to_s
      total = 0

      Spree::ActedBy.models.each do |model|
        model.acted_by_associations.each do |name|
          count = model.
                  where.not(:"#{name}_id" => nil).
                  where(:"#{name}_type" => nil).
                  in_batches.
                  sum { |batch| batch.update_all(:"#{name}_type" => actor_type) }

          next if count.zero?

          total += count
          puts "  #{model.table_name}.#{name}: #{count} row(s) set to #{actor_type}."
        end
      end

      puts total.zero? ? '  Nothing to backfill.' : "  Backfilled #{total} actor reference(s)."
    end
  end
end
