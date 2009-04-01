require File.dirname(__FILE__) + '/../test_helper'

require 'dog'
require 'wild_boar'
require 'frog'
require 'cat'
require 'kitten'
require 'aquatic/whale'
require 'aquatic/fish'
require 'aquatic/pupils_whale'
require 'beautiful_fight_relationship' 

class PolymorphTest < ActiveSupport::TestCase
  
  set_fixture_class :bow_wows => Dog
  set_fixture_class :keep_your_enemies_close => BeautifulFightRelationship
  set_fixture_class :whales => Aquatic::Whale
  set_fixture_class :fish => Aquatic::Fish
  set_fixture_class :little_whale_pupils => Aquatic::PupilsWhale
  
  fixtures :cats, :bow_wows, :frogs, :wild_boars, :eaters_foodstuffs, :petfoods,
              :fish, :whales, :little_whale_pupils, :keep_your_enemies_close, :people   
        
  def setup
   @association_error = ActiveRecord::Associations::PolymorphicError
   @kibbles = Petfood.find(1)
   @bits = Petfood.find(2) 
   @shamu = Aquatic::Whale.find(1)
   @swimmy = Aquatic::Fish.find(1)
   @rover = Dog.find(1)
   @spot = Dog.find(2)
   @puma  = WildBoar.find(1)
   @chloe = Kitten.find(1)
   @alice = Kitten.find(2)
   @toby = Tabby.find(3)
   @froggy = Frog.find(1)

   @join_count = EatersFoodstuff.count    
   @kibbles_eaters_count = @kibbles.eaters.size
   @bits_eaters_count = @bits.eaters.size

   @double_join_count = BeautifulFightRelationship.count
   @alice_enemies_count = @alice.enemies.size
  end  
  
  def test_all_relationship_validities
    # q = []
    # ObjectSpace.each_object(Class){|c| q << c if c.ancestors.include? ActiveRecord::Base }
    # q.each{|c| puts "#{c.name}.reflect_on_all_associations.map(&:check_validity!)"}
    Petfood.reflect_on_all_associations.map(&:check_validity!)
    Tabby.reflect_on_all_associations.map(&:check_validity!)
    Kitten.reflect_on_all_associations.map(&:check_validity!)
    Dog.reflect_on_all_associations.map(&:check_validity!)
    Canine.reflect_on_all_associations.map(&:check_validity!)
    Aquatic::Fish.reflect_on_all_associations.map(&:check_validity!)
    EatersFoodstuff.reflect_on_all_associations.map(&:check_validity!)
    WildBoar.reflect_on_all_associations.map(&:check_validity!)
    Frog.reflect_on_all_associations.map(&:check_validity!)
    Cat.reflect_on_all_associations.map(&:check_validity!)
    BeautifulFightRelationship.reflect_on_all_associations.map(&:check_validity!)
    Person.reflect_on_all_associations.map(&:check_validity!)
    Parentship.reflect_on_all_associations.map(&:check_validity!)
    Aquatic::Whale.reflect_on_all_associations.map(&:check_validity!)
    Aquatic::PupilsWhale.reflect_on_all_associations.map(&:check_validity!)
  end
  
  def test_assignment     
    assert @kibbles.eaters.blank?
    assert @kibbles.eaters.push(Cat.find_by_name('Chloe'))
    assert_equal @kibbles_eaters_count += 1, @kibbles.eaters.count

    @kibbles.reload
    assert_equal @kibbles_eaters_count, @kibbles.eaters.count    
  end
  
  def test_duplicate_assignment
    # try to add a duplicate item when :ignore_duplicates is false
    @kibbles.eaters.push(@alice)
    assert @kibbles.eaters.any? {|obj| obj == @alice}
    @kibbles.eaters.push(@alice)
    assert_equal @kibbles_eaters_count + 2, @kibbles.eaters.count
    assert_equal @join_count + 2, EatersFoodstuff.count
  end
  
  def test_create_and_push
    assert @kibbles.eaters.push(@spot)  
    assert_equal @kibbles_eaters_count += 1, @kibbles.eaters.count
    assert @kibbles.eaters << @rover
    assert @kibbles.eaters << Kitten.create(:name => "Miranda")
    assert_equal @kibbles_eaters_count += 2, @kibbles.eaters.length

    @kibbles.reload
    assert_equal @kibbles_eaters_count, @kibbles.eaters.length   
    
    # test that ids and new flags were set appropriately
    assert_not_nil @kibbles.eaters[0].id
    assert !@kibbles.eaters[1].new_record?
  end
 
  def test_reload
    assert @kibbles.reload
    assert @kibbles.eaters.reload
  end
 
  def test_add_join_record
    assert_equal Kitten, @chloe.class
    assert join = EatersFoodstuff.new(:foodstuff_id => @bits.id, :eater_id => @chloe.id, :eater_type => @chloe.class.name ) 
    assert join.save!
    assert join.id
    assert_equal @join_count + 1, EatersFoodstuff.count

    #assert_equal @bits_eaters_count, @bits.eaters.size # Doesn't behave this way on latest edge anymore
    assert_equal @bits_eaters_count + 1, @bits.eaters.count # SQL

    # reload; is the new association there?
    assert @bits.eaters.reload
    assert @bits.eaters.any? {|obj| obj == @chloe}
  end

  def test_build_join_record_on_association
    assert_equal Kitten, @chloe.class
    assert join = @chloe.eaters_foodstuffs.build(:foodstuff => @bits)
    # assert_equal join.eater_type, @chloe.class.name # will be STI parent type
    assert join.save!
    assert join.id
    assert_equal @join_count + 1, EatersFoodstuff.count

    assert @bits.eaters.reload
    assert @bits.eaters.any? {|obj| obj == @chloe}
  end

#  not supporting this, since has_many :through doesn't support it either  
#  def test_add_unsaved   
#    # add an unsaved item
#    assert @bits.eaters << Kitten.new(:name => "Bridget")
#    assert_nil Kitten.find_by_name("Bridget")
#    assert_equal @bits_eaters_count + 1, @bits.eaters.count
#
#    assert @bits.save
#    @bits.reload
#    assert_equal @bits_eaters_count + 1, @bits.eaters.count
#    
#  end
  
  def test_self_reference
    assert @kibbles.eaters << @bits
    assert_equal @kibbles_eaters_count += 1, @kibbles.eaters.count
    assert @kibbles.eaters.any? {|obj| obj == @bits}
    @kibbles.reload
    assert @kibbles.foodstuffs_of_eaters.blank?
    
    @bits.reload
    assert @bits.foodstuffs_of_eaters.any? {|obj| obj == @kibbles}
    assert_equal [@kibbles], @bits.foodstuffs_of_eaters
  end

  def test_remove
    assert @kibbles.eaters << @chloe
    @kibbles.reload
    assert @kibbles.eaters.delete(@kibbles.eaters[0])
    assert_equal @kibbles_eaters_count, @kibbles.eaters.count
  end
  
  def test_destroy
    assert @kibbles.eaters.push(@chloe)
    @kibbles.reload
    assert @kibbles.eaters.length > 0
    assert @kibbles.eaters[0].destroy
    @kibbles.reload
    assert_equal @kibbles_eaters_count, @kibbles.eaters.count
  end

  def test_clear
    @kibbles.eaters << [@chloe, @spot, @rover]
    @kibbles.reload
    assert @kibbles.eaters.clear.blank?    
    assert @kibbles.eaters.blank?    
    @kibbles.reload    
    assert @kibbles.eaters.blank?    
  end
    
  def test_individual_collections
    assert @kibbles.eaters.push(@chloe)
    # check if individual collections work
    assert_equal @kibbles.eater_kittens.length, 1
    assert @kibbles.eater_dogs 
    assert 1, @rover.eaters_foodstuffs.count
  end
  
  def test_individual_collections_push
    assert_equal [@chloe], (@kibbles.eater_kittens << @chloe)
    @kibbles.reload
    assert @kibbles.eaters.any? {|obj| obj == @chloe}
    assert @kibbles.eater_kittens.any? {|obj| obj == @chloe}
    assert !@kibbles.eater_dogs.any? {|obj| obj == @chloe}
  end

  def test_individual_collections_delete
    @kibbles.eaters << [@chloe, @spot, @rover]
    @kibbles.reload
    assert_equal [@chloe], @kibbles.eater_kittens.delete(@chloe)
    assert @kibbles.eater_kittens.empty?
    @kibbles.eater_kittens.delete(@chloe) # what should this return?
    
    @kibbles.reload    
    assert @kibbles.eater_kittens.empty?
    assert @kibbles.eater_dogs.any? {|obj| obj == @spot}
  end
  
  def test_individual_collections_clear
    @kibbles.eaters << [@chloe, @spot, @rover]
    @kibbles.reload

    assert_equal [], @kibbles.eater_kittens.clear
    assert @kibbles.eater_kittens.empty?    
    assert_equal 2, @kibbles.eaters.size

    assert @kibbles.eater_kittens.empty?    
    assert_equal 2, @kibbles.eaters.size
    assert !@kibbles.eater_kittens.any? {|obj| obj == @chloe}
    assert !@kibbles.eaters.any? {|obj| obj == @chloe}

    @kibbles.reload    
    assert @kibbles.eater_kittens.empty?    
    assert_equal 2, @kibbles.eaters.size
    assert !@kibbles.eater_kittens.any? {|obj| obj == @chloe}
    assert !@kibbles.eaters.any? {|obj| obj == @chloe}
  end
  
  def test_childrens_individual_collections
    assert Cat.find_by_name('Chloe').eaters_foodstuffs
    assert @kibbles.eaters_foodstuffs
  end
  
  def test_self_referential_join_tables
    # check that the self-reference join tables go the right ways
    assert_equal @kibbles_eaters_count, @kibbles.eaters_foodstuffs.count
    assert_equal @kibbles.eaters_foodstuffs.count, @kibbles.eaters_foodstuffs_as_child.count
  end

  def test_dependent
    assert @kibbles.eaters << @chloe
    @kibbles.reload
 
    # delete ourself and see if :dependent was obeyed
    dependent_rows = @kibbles.eaters_foodstuffs
    assert_equal dependent_rows.length, @kibbles.eaters.count
    @join_count = EatersFoodstuff.count
    
    @kibbles.destroy
    assert_equal @join_count - dependent_rows.length, EatersFoodstuff.count
    assert_equal 0, EatersFoodstuff.find(:all, :conditions => ['foodstuff_id = ?', 1] ).length
  end
  
  def test_normal_callbacks
    assert @rover.respond_to?(:after_initialize)
    assert @rover.respond_to?(:after_find)    
    assert @rover.after_initialize_test
    assert @rover.after_find_test
  end    
  
  def test_model_callbacks_not_overridden_by_plugin_callbacks
    assert 0, @bits.eaters.count
    assert @bits.eaters.push(@rover)
    @bits.save
    @bits2 = Petfood.find_by_name("Bits")
    @bits.reload
    assert rover = @bits2.eaters.select { |x| x.name == "Rover" }[0]
    assert rover.after_initialize_test
    assert rover.after_find_test
  end

  def test_number_of_join_records
    assert EatersFoodstuff.create(:foodstuff_id => 1, :eater_id => 1, :eater_type => "Cat")
    @join_count = EatersFoodstuff.count    
    assert @join_count > 0
  end
  
  def test_number_of_regular_records
    dogs = Dog.count
    assert Dog.new(:name => "Auggie").save!
    assert dogs + 1, Dog.count
  end

  def test_attributes_come_through_when_child_has_underscore_in_table_name
    join = EatersFoodstuff.new(:foodstuff_id => @bits.id, :eater_id =>  @puma.id, :eater_type => @puma.class.name) 
    join.save!
    
    @bits.eaters.reload

    assert_equal "Puma", @puma.name
    assert_equal "Puma", @bits.eaters.first.name
  end
  
  
  def test_before_save_on_join_table_is_not_clobbered_by_sti_base_class_fix
    assert @kibbles.eaters << @chloe
    assert_equal 3, @kibbles.eaters_foodstuffs.first.some_attribute
  end
  
  def test_sti_type_counts_are_correct
    @kibbles.eaters << [@chloe, @alice, @toby]
    assert_equal 2, @kibbles.eater_kittens.count
    assert_equal 1, @kibbles.eater_tabbies.count
    assert !@kibbles.respond_to?(:eater_cats)
  end
  
    
  def test_creating_namespaced_relationship
    assert @shamu.aquatic_pupils.empty?
    @shamu.aquatic_pupils << @swimmy
    assert_equal 1, @shamu.aquatic_pupils.length
    @shamu.reload
    assert_equal 1, @shamu.aquatic_pupils.length
  end  

  def test_namespaced_polymorphic_collection
    @shamu.aquatic_pupils << @swimmy
    assert @shamu.aquatic_pupils.any? {|obj| obj == @swimmy}
    @shamu.reload
    assert @shamu.aquatic_pupils.any? {|obj| obj == @swimmy}

    @shamu.aquatic_pupils << @spot
    assert @shamu.dogs.any? {|obj| obj == @spot}
    assert @shamu.aquatic_pupils.any? {|obj| obj == @swimmy}
    assert_equal @swimmy, @shamu.aquatic_fish.first
    assert_equal 10, @shamu.aquatic_fish.first.speed
  end
  
  def test_deleting_namespaced_relationship    
    @shamu.aquatic_pupils << @swimmy
    @shamu.aquatic_pupils << @spot
    
    @shamu.reload
    @shamu.aquatic_pupils.delete @spot
    assert !@shamu.dogs.any? {|obj| obj == @spot}
    assert !@shamu.aquatic_pupils.any? {|obj| obj == @spot}
    assert_equal 1, @shamu.aquatic_pupils.length
  end
  
  def test_unrenamed_parent_of_namespaced_child
    @shamu.aquatic_pupils << @swimmy
    assert_equal [@shamu], @swimmy.whales
  end
  
  def test_empty_double_collections
    assert @puma.enemies.empty?
    assert @froggy.protectors.empty?
    assert @alice.enemies.empty?
    assert @spot.protectors.empty?
    assert @alice.beautiful_fight_relationships_as_enemy.empty?
    assert @alice.beautiful_fight_relationships_as_protector.empty?
    assert @alice.beautiful_fight_relationships.empty?    
  end
  
  def test_double_collection_assignment
    @alice.enemies << @spot
    @alice.reload
    @spot.reload
    assert @spot.protectors.any? {|obj| obj == @alice}
    assert @alice.enemies.any? {|obj| obj == @spot}
    assert !@alice.protectors.any? {|obj| obj == @alice}
    assert_equal 1, @alice.beautiful_fight_relationships_as_protector.size
    assert_equal 0, @alice.beautiful_fight_relationships_as_enemy.size
    assert_equal 1, @alice.beautiful_fight_relationships.size
    
    # self reference
    assert_equal 1, @alice.enemies.length
    @alice.enemies.push @alice
    assert @alice.enemies.any? {|obj| obj == @alice}
    assert_equal 2, @alice.enemies.length    
    @alice.reload
    assert_equal 2, @alice.beautiful_fight_relationships_as_protector.size
    assert_equal 1, @alice.beautiful_fight_relationships_as_enemy.size
    assert_equal 3, @alice.beautiful_fight_relationships.size
  end
  
  def test_double_collection_build_join_record_on_association
    
    join = @alice.beautiful_fight_relationships_as_protector.build(:enemy => @spot)
    
    assert_equal @alice.class.base_class.name, join.protector_type
    assert_nothing_raised { join.save! }

    assert join.id
    assert_equal @double_join_count + 1, BeautifulFightRelationship.count

    assert @alice.enemies.reload
    assert @alice.enemies.any? {|obj| obj == @spot}
  end
  
  def test_double_dependency_injection
#    breakpoint
  end
  
  def test_double_collection_deletion
    @alice.enemies << @spot
    @alice.reload
    assert @alice.enemies.any? {|obj| obj == @spot}
    @alice.enemies.delete(@spot)
    assert !@alice.enemies.any? {|obj| obj == @spot}
    assert @alice.enemies.empty?
    @alice.reload
    assert !@alice.enemies.any? {|obj| obj == @spot}
    assert @alice.enemies.empty?
    assert_equal 0, @alice.beautiful_fight_relationships.size
  end
 
  def test_double_collection_deletion_from_opposite_side
    @alice.protectors << @puma
    @alice.reload
    assert @alice.protectors.any? {|obj| obj == @puma}
    @alice.protectors.delete(@puma)
    assert !@alice.protectors.any? {|obj| obj == @puma}
    assert @alice.protectors.empty?
    @alice.reload
    assert !@alice.protectors.any? {|obj| obj == @puma}
    assert @alice.protectors.empty?
    assert_equal 0, @alice.beautiful_fight_relationships.size
  end
 
  def test_individual_collections_created_for_double_relationship
    assert @alice.dogs.empty?
    @alice.enemies << @spot

    assert @alice.enemies.any? {|obj| obj == @spot}
    assert !@alice.kittens.any? {|obj| obj == @alice}    

    assert !@alice.dogs.any? {|obj| obj == @spot}    
    @alice.reload
    assert @alice.dogs.any? {|obj| obj == @spot}    
    assert !WildBoar.find(@alice.id).dogs.any? {|obj| obj == @spot} # make sure the parent type is checked
  end

  def test_individual_collections_created_for_double_relationship_from_opposite_side
    assert @alice.wild_boars.empty?
    @alice.protectors << @puma
    @alice.reload

    assert @alice.protectors.any? {|obj| obj == @puma}
    assert @alice.wild_boars.any? {|obj| obj == @puma}    
    
    assert !Dog.find(@alice.id).wild_boars.any? {|obj| obj == @puma} # make sure the parent type is checked
  end
  
  def test_self_referential_individual_collections_created_for_double_relationship
    @alice.enemies << @alice
    @alice.reload
    assert @alice.enemy_kittens.any? {|obj| obj == @alice}
    assert @alice.protector_kittens.any? {|obj| obj == @alice}
    assert @alice.kittens.any? {|obj| obj == @alice}
    assert_equal 2, @alice.kittens.size

    @alice.enemies << (@chloe =  Kitten.find_by_name('Chloe'))
    @alice.reload
    assert @alice.enemy_kittens.any? {|obj| obj == @chloe}
    assert !@alice.protector_kittens.any? {|obj| obj == @chloe}
    assert @alice.kittens.any? {|obj| obj == @chloe}
    assert_equal 3, @alice.kittens.size    
  end
    
  def test_child_of_polymorphic_join_can_reach_parent
    @alice.enemies << @spot    
    @alice.reload
    assert @spot.protectors.any? {|obj| obj == @alice}
  end
  
  def test_double_collection_deletion_from_child_polymorphic_join
    @alice.enemies << @spot
    @spot.protectors.delete(@alice)
    assert !@spot.protectors.any? {|obj| obj == @alice}
    @alice.reload
    assert !@alice.enemies.any? {|obj| obj == @spot}
    BeautifulFightRelationship.create(:protector_id => 2, :protector_type => "Dog", :enemy_id => @spot.id, :enemy_type => @spot.class.name)
    @alice.enemies << @spot
    @spot.protectors.delete(@alice)
    assert !@spot.protectors.any? {|obj| obj == @alice}
  end

  def test_collection_query_on_unsaved_record
    assert Dog.new.enemies.empty?
    assert Dog.new.foodstuffs_of_eaters.empty?
  end
 
  def test_double_individual_collections_push
    assert_equal [@chloe], (@spot.protector_kittens << @chloe)
    @spot.reload
    assert @spot.protectors.any? {|obj| obj == @chloe}
    assert @spot.protector_kittens.any? {|obj| obj == @chloe}
    assert !@spot.protector_dogs.any? {|obj| obj == @chloe}
 
    assert_equal [@froggy], (@spot.frogs << @froggy)
    @spot.reload
    assert @spot.enemies.any? {|obj| obj == @froggy}
    assert @spot.frogs.any? {|obj| obj == @froggy}
    assert !@spot.enemy_dogs.any? {|obj| obj == @froggy}
  end

  def test_double_individual_collections_delete
    @spot.protectors << [@chloe, @puma]
    @spot.reload
    assert_equal [@chloe], @spot.protector_kittens.delete(@chloe)
    assert @spot.protector_kittens.empty?
    @spot.protector_kittens.delete(@chloe) # again, unclear what .delete should return
    
    @spot.reload    
    assert @spot.protector_kittens.empty?
    assert @spot.wild_boars.any? {|obj| obj == @puma}
  end
  
  def test_double_individual_collections_clear
    @spot.protectors << [@chloe, @puma, @alice]
    @spot.reload
    assert_equal [], @spot.protector_kittens.clear
    assert @spot.protector_kittens.empty?    
    assert_equal 1, @spot.protectors.size
    @spot.reload    
    assert @spot.protector_kittens.empty?    
    assert_equal 1, @spot.protectors.size
    assert !@spot.protector_kittens.any? {|obj| obj == @chloe}
    assert !@spot.protectors.any? {|obj| obj == @chloe}
    assert !@spot.protector_kittens.any? {|obj| obj == @alice}
    assert !@spot.protectors.any? {|obj| obj == @alice}
    assert @spot.protectors.any? {|obj| obj == @puma}
    assert @spot.wild_boars.any? {|obj| obj == @puma}
  end 

  def test_single_extensions
    assert_equal :correct_block_result, @shamu.aquatic_pupils.a_method
    @kibbles.eaters.push(@alice)
    @kibbles.eaters.push(@spot)
    assert_equal :correct_join_result, @kibbles.eaters_foodstuffs.a_method
    assert_equal :correct_module_result, @kibbles.eaters.a_method
    assert_equal :correct_other_module_result, @kibbles.eaters.another_method
    @kibbles.eaters.each do |eater| 
      assert_equal :correct_join_result, eater.eaters_foodstuffs.a_method
    end
    assert_equal :correct_parent_proc_result, @kibbles.foodstuffs_of_eaters.a_method
    assert_equal :correct_parent_proc_result, @kibbles.eaters.first.foodstuffs_of_eaters.a_method
  end

  def test_double_extensions
    assert_equal :correct_proc_result, @spot.protectors.a_method 
    assert_equal :correct_module_result, @spot.enemies.a_method 
    assert_equal :correct_join_result, @spot.beautiful_fight_relationships_as_enemy.a_method
    assert_equal :correct_join_result, @spot.beautiful_fight_relationships_as_protector.a_method
    assert_equal :correct_join_result, @froggy.beautiful_fight_relationships.a_method
    assert_equal :correct_join_result, @froggy.beautiful_fight_relationships_as_enemy.a_method    
    assert_raises(NoMethodError) {@froggy.beautiful_fight_relationships_as_protector.a_method}    
  end
  
  def test_pluralization_checks    
    assert_raises(@association_error) {
      eval "class SomeModel < ActiveRecord::Base
        has_many_polymorphs :polymorphs, :from => [:dog, :cats]
      end" }
    assert_raises(@association_error) {
      eval "class SomeModel < ActiveRecord::Base
        has_many_polymorphs :polymorph, :from => [:dogs, :cats]
      end" }
    assert_raises(@association_error) {
      eval "class SomeModel < ActiveRecord::Base
        acts_as_double_polymorphic_join :polymorph => [:dogs, :cats], :unimorphs => [:dogs, :cats]
      end" }    
  end
  
  def test_error_message_on_namespaced_targets
    assert_raises(@association_error) {
      eval "class SomeModel < ActiveRecord::Base
        has_many_polymorphs :polymorphs, :from => [:fish]
      end" }
  end

  def test_single_custom_finders
    [@kibbles, @alice, @puma, @spot, @bits].each {|record| @kibbles.eaters << record; sleep 1} # XXX yeah i know
    assert_equal @kibbles.eaters, @kibbles.eaters.find(:all, :order => "eaters_foodstuffs.created_at ASC") 
    assert_equal @kibbles.eaters.reverse, @kibbles.eaters.find(:all, :order => "eaters_foodstuffs.created_at DESC") 
    if (ActiveRecord::Base.connection.is_a? ActiveRecord::ConnectionAdapters::MysqlAdapter rescue false)
      assert_equal @kibbles.eaters.sort_by(&:created_at), @kibbles.eaters.find(:all, :order => "IFNULL(bow_wows.created_at,(IFNULL(petfoods.created_at,(IFNULL(wild_boars.created_at,(IFNULL(cats.created_at,fish.created_at))))))) ASC") 
    end
    assert_equal @kibbles.eaters.select{|x| x.is_a? Petfood}, @kibbles.eater_petfoods.find(:all, :order => "eaters_foodstuffs.created_at ASC") 
  end
 
  def test_double_custom_finders
    @spot.protectors << [@chloe, @puma, @alice]
    assert_equal [@chloe], @spot.protectors.find(:all, :conditions => ["cats.name = ?", @chloe.name], :limit => 1)
    assert_equal [], @spot.protectors.find(:all, :conditions => ["cats.name = ?", @chloe.name], :limit => 1, :offset => 1)
    assert_equal 2, @spot.protectors.find(:all, :limit => 100, :offset => 1).size
  end
  
  def test_single_custom_finder_parameters_carry_to_individual_relationships
   # XXX test nullout here
  end

  def test_double_custom_finder_parameters_carry_to_individual_relationships
   # XXX test nullout here
  end
  
  def test_include_doesnt_fail
    assert_nothing_raised do
      @spot.protectors.find(:all, :include => :wild_boars)
    end
  end

  def test_abstract_method
    assert_equal :correct_abstract_method_response, @spot.an_abstract_method
  end
  
  def test_missing_target_should_raise
    @kibbles.eaters << [@kibbles, @alice, @puma, @spot, @bits]
    @spot.destroy_without_callbacks
    assert_raises(@association_error) { @kibbles.eaters.reload }
#    assert_raises(@association_error) { @kibbles.eater_dogs.reload }  # bah AR
  end
  
  def test_lazy_loading_is_lazy
    # XXX
  end
  
  def test_push_with_skip_duplicates_false_doesnt_load_target
    # Loading kibbles locally again because setup calls .size which loads target
    kibbles = Petfood.find(1)
    assert !kibbles.eaters.loaded?
    assert !(kibbles.eater_dogs << Dog.create!(:name => "Mongy")).loaded?
    assert !kibbles.eaters.loaded?
  end
  
  def test_association_foreign_key_is_sane
    assert_equal "eater_id", Petfood.reflect_on_association(:eaters).association_foreign_key
  end

  def test_reflection_instance_methods_are_sane
    assert_equal EatersFoodstuff, Petfood.reflect_on_association(:eaters).klass
    assert_equal EatersFoodstuff.name, Petfood.reflect_on_association(:eaters).class_name
  end
  
  def test_parent_order
    @alice.foodstuffs_of_eaters << Petfood.find(:all, :order => "the_petfood_primary_key ASC")
    @alice.reload #not necessary
    assert_equal [2,1], @alice.foodstuffs_of_eaters.map(&:id)  
  end

  def test_parent_conditions
    @kibbles.eaters << @alice
    assert_equal [@alice], @kibbles.eaters

    @snausages = Petfood.create(:name => 'Snausages')
    @snausages.eaters << @alice    
    assert_equal [@alice], @snausages.eaters
    
    assert_equal [@kibbles], @alice.foodstuffs_of_eaters
  end        
  
  def test_self_referential_hmp_with_conditions
    p = Person.find(:first)
    kid = Person.create(:name => "Tim", :age => 3)
    p.kids << kid

    kid.reload; p.reload

  # assert_equal [p], kid.parents 
  # assert Rails.has_one? Bug
  # non-standard foreign_type key is not set properly when you are the polymorphic interface of a has_many going to a :through

    assert_equal [kid], p.kids
    assert_equal [kid], p.people
  end

#  def test_polymorphic_include
#    @kibbles.eaters << [@kibbles, @alice, @puma, @spot, @bits]
#    assert @kibbles.eaters.include?(@kibbles.eaters_foodstuffs.find(:all, :include => :eater).first.eater)
#  end
#
#  def test_double_polymorphic_include
#  end
#
#  def test_single_child_include  
#  end
#  
#  def test_double_child_include  
#  end
#  
#  def test_single_include_from_parent  
#  end
#
#  def test_double_include_from_parent  
#  end
#
#  def test_meta_referential_single_include  
#  end
#
#  def test_meta_referential_double_include  
#  end
#  
#  def test_meta_referential_single_include  
#  end
#
#  def test_meta_referential_single_double_multi_include  
#  end  
#  
#  def test_dont_ignore_duplicates  
#  end
#
#  def test_ignore_duplicates  
#  end
#    
#  def test_tagging_system_generator  
#  end
#
#  def test_tagging_system_library  
#  end

end
