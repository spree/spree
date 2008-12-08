class Taxon < ActiveRecord::Base
  acts_as_adjacency_list :foreign_key => 'parent_id', :order => 'position'
  belongs_to :taxonomy
  has_and_belongs_to_many :products
  before_save :set_permalink  
    
  private
  def set_permalink
    ancestors.reverse.collect { |ancestor| ancestor.name }.join( "/")
    prefix = ancestors.reverse.collect { |ancestor| escape(ancestor.name) }.join( "/")
    prefix += "/" unless prefix.blank?
    self.permalink =  prefix + "#{escape(name)}/"
  end
  
  # taken from the find_by_param plugin
  def escape(str)
    return "" if str.blank? # hack if the str/attribute is nil/blank
    s = Iconv.iconv('ascii//ignore//translit', 'utf-8', str.dup).to_s
    returning str.dup.to_s do |s|
      s.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
      s.gsub!(/[^\w^-]+/, '') # kill non-word chars except -
      s.strip!            # ohh la la
      s.downcase!         # :D
      s.gsub!(/([^ a-zA-Z0-9_-]+)/n,"") # and now kill every char not allowed.
    end
  end
  
end
