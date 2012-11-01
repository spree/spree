

# check for incorect product assets path in public directory
if File.exist?(Rails.root.join("public/assets/products")) ||  File.exist?(Rails.root.join("public/assets/taxons"))
  puts %q{[DEPRECATION] Your applications public directory contains an assets/products and/or assets/taxons subdirectory. 
    Run `rake spree:assets:relocate_images` to relocate the images.}
end
