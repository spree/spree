require 'acts-as-taggable-on'
if ActsAsTaggableOn::Utils.using_mysql?
  ActsAsTaggableOn.force_binary_collation = true
end
