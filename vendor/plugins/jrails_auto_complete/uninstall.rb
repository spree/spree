puts "Removing files..."
dir = "javascripts"
["jrails.autocomplete.js"].each do |js_file|
	dest_file = File.join(RAILS_ROOT, "public", dir, js_file)
	FileUtils.rm_r(src_file, dest_file)
end
puts "Files removed - Uninstallation complete!"