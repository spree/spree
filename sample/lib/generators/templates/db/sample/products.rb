# make sure the product images directory exists
FileUtils.mkdir_p "#{Rails.root}/public/assets/products/"

Asset.all.each do |asset|
  filename = asset.attachment_file_name
  puts "-- Processing image: #{filename}\r"
  path = File.join(File.dirname(__FILE__), "assets/#{filename}")

  if FileTest.exists? path
    asset.attachment = File.open(path)
    asset.save
  else
    puts "--- Could not find image at: #{path}"
  end
end
