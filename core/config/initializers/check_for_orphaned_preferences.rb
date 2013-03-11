begin
  required_column_names = ["owner_id", "owner_type", "name"]     
  if (Spree::Preference.column_names & required_column_names) == required_column_names
     ActiveRecord::Base.connection.execute("SELECT owner_id, owner_type, name, value FROM spree_preferences WHERE 'key' IS NULL").each do |pref|
       warn "[WARNING] Orphaned preference `#{pref[2]}` with value `#{pref[3]}` for #{pref[1]} with id of: #{pref[0]}, you should reset the preference value manually."
     end
  end
rescue
end
