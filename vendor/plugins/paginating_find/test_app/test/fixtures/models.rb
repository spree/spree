class Author < ActiveRecord::Base
  has_many :edits
end

class Edit < ActiveRecord::Base
  belongs_to :author
  belongs_to :article
end

class Article < ActiveRecord::Base
  has_many :edits
  has_many :editors, :through => :edits, :source => :author
  belongs_to :author
  
  def self.find_with_scope(options={}, &block)
    with_scope(:find => options, &block)
  end
end