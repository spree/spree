class Taxon < ActiveRecord::Base; end;

class RemoveTrailingSlashesInTaxonPermalinks < ActiveRecord::Migration
  def up
    Taxon.find_each(:conditions => {}) do |t|
      if t.permalink && t.permalink[-1..-1] == '/'
        t.update_attribute(:permalink, t.permalink[0...-1])
      end
    end
  end

  def down
    Taxon.find_each(:conditions => {}) do |t|
      if t.permalink && t.permalink[-1..-1] != '/'
        t.update_attribute(:permalink, t.permalink + '/')
      end
    end
  end
end
