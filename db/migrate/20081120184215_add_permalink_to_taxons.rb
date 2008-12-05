require "#{SPREE_ROOT}/vendor/plugins/find_by_param/lib/find_by_param.rb"

class AddPermalinkToTaxons < ActiveRecord::Migration
  extend Railslove::Plugins::FindByParam::SingletonMethods
  
  def self.up
    add_column :taxons, :permalink, :string
    
    Taxon.find(:all).each do |taxon| 
      taxon.permalink = ""
      t = taxon
      until t.nil?
        taxon.permalink = escape(t.name) + "/" + taxon.permalink
        t = t.parent
      end

      taxon.save!
    end
  end

  def self.down
    remove_column :taxons, :permalink
  end
end
