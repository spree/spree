namespace :spree do
  namespace :uploads do
    desc <<~DESC
      Gives every attached file the store of the record it is attached to
      (Spree 6.0). Idempotent — files that already have a store are skipped.
      Files attached in more than one store are listed, not changed.
    DESC
    task assign_stores: :environment do
      result = Spree::Uploads::AssignStores.call
      puts "  Assigned a store to #{result.value[:assigned]} file(s)."

      conflicts = result.value[:conflicts]
      next if conflicts.empty?

      puts "  #{conflicts.size} file(s) are attached to records of more than one store and were left as they are:"
      conflicts.each { |blob_id| puts "    active_storage_blobs.id = #{blob_id}" }
    end
  end
end
