require "acts-as-taggable-on"
if ActsAsTaggableOn::Utils.using_mysql?
  ActsAsTaggableOn.force_binary_collation = true
end

ActsAsTaggableOn::Tag.class_eval do
  self.table_name_prefix = "spree_"
end

ActsAsTaggableOn::Tagging.class_eval do
  self.table_name_prefix = "spree_"
end
