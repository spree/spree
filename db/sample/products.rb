require 'find'
# make sure the product images directory exists
FileUtils.mkdir_p "#{RAILS_ROOT}/public/assets/products/"

# make product images available to the app
target = "#{RAILS_ROOT}/public/assets/products/"
source = "#{SPREE_ROOT}/lib/tasks/sample/products/"

Find.find(source) do |f|
  # omit hidden directories (SVN, etc.)
  if File.basename(f) =~ /^[.]/
    Find.prune
    next
  end

  src_path = source + f.sub(source, '')
  target_path = target + f.sub(source, '')

  if File.directory?(f)
    FileUtils.mkdir_p target_path
  else
    FileUtils.cp src_path, target_path
  end
end
