require 'camping'
require 'has_many_polymorphs'

Camping.goes :Hmph

module Hmph::Models
  class GuestsKennel < Base
    belongs_to :kennel
    belongs_to :guest, :polymorphic => true
  end

  class Dog < Base
  end

  class Cat < Base
  end

  class Bird < Base
  end
  
  class Kennel < Base
    has_many_polymorphs :guests, 
      :from => [:dogs, :cats, :birds],
      :through => :guests_kennels,
      :namespace => :"hmph/models/"      
  end  

  class InitialSchema < V 1.0
    def self.up
      create_table :hmph_kennels do |t|
        t.column :created_at, :datetime
        t.column :modified_at, :datetime
        t.column :name, :string, :default => 'Anonymous Kennel'
      end

      create_table :hmph_guests_kennels do |t|
        t.column :guest_id, :integer
        t.column :guest_type, :string
        t.column :kennel_id, :integer
      end

      create_table :hmph_dogs do |t|
        t.column :name, :string, :default => 'Fido'
      end

      create_table :hmph_cats do |t|
        t.column :name, :string, :default => 'Morris'
      end

      create_table :hmph_birds do |t|
        t.column :name, :string, :default => 'Polly'
      end
    end

    def self.down
      drop_table :hmph_kennels
      drop_table :hmph_guests_kennels
      drop_table :hmph_dogs
      drop_table :hmph_cats
      drop_table :hmph_birds
    end
  end
end

module Hmph::Controllers
end

module Hmph::Views
end
