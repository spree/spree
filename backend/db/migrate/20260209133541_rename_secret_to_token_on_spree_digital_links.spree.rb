# This migration comes from spree (originally 20210930143043)
class RenameSecretToTokenOnSpreeDigitalLinks < ActiveRecord::Migration[5.2]
  def change
    rename_column :spree_digital_links, :secret, :token
  end
end
