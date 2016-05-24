# This migration is added to circumvent issue #623 and have special characters
# work properly
class ChangeCollationForSpreeTagNames < ActiveRecord::Migration
  def up
    if ActsAsTaggableOn::Utils.using_mysql?
      execute("ALTER TABLE spree_tags MODIFY name varchar(255) CHARACTER SET utf8 COLLATE utf8_bin;")
    end
  end
end
