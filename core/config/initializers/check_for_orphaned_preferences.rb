begin
  ActiveRecord::Base.connection.execute("select owner_id, owner_type, name, value from spree_preferences where 'key' is null").each do |pref|
    warn "[WARNING] Orphaned preference `#{pref[2]}` with value `#{pref[3]}` for #{pref[1]} with id of: #{pref[0]}, you should reset the preference value manually."
  end
rescue
end
