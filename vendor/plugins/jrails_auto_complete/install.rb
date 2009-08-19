puts "Copying files..."
dir = "javascripts"
["jrails.autocomplete.js"].each do |js_file|
	dest_file = File.join(RAILS_ROOT, "public", dir, js_file)
	src_file = File.join(File.dirname(__FILE__) , dir, js_file)
	FileUtils.cp_r(src_file, dest_file)
end
puts "Files copied - Installation complete!"