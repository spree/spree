require File.dirname(__FILE__) + '/../test_helper'

class PhotoTest < ActiveSupport::TestCase
  should_have_many :comments
  
  context "comment_attributes" do
    context "with valid children" do
      setup do
        create_photo_and_children
      
        @photo.comment_attributes = { @gob.id.to_s => { :author => "Buster Bluth", :body => "I said it was _our_ nausia..." },
                                      :new         => { "0" => { :author => "George-Michael", :body => "I was going to smoke the marijuana like a ciggarette." },
                                                        "-1" => { :author => "Tobias Funke", :body => "I am an actor! An actor for crying out loud!" }}}
      
      end
    
      context "before save" do
        should "not have deleted anything in the remove array" do
          assert @photo.comments.any? { |comment| comment.author == "Bob Loblaw" }, "Comment in remove array was removed."
        end
      
        should "not have saved any new objects" do
          assert @photo.comments.any? { |comment| comment.new_record? }
        end
      end
    
      context "after save" do
        setup do
          @photo.save
        end

        context "with existing child" do
          setup do
            @gob.reload
          end

          should "update attributes" do
            assert_equal "Buster Bluth", @gob.author, "Author attribute of child model was not updated."
            assert_equal "I said it was _our_ nausia...", @gob.body, "Body attribute of child model was not updated."
          end
        end
    
        context "with new hash" do
          should "create new comment" do
            assert @photo.comments.any? { |comment| comment.author == "George-Michael" && comment.body =~ /was going to smoke/i }, "New comment was not created."
          end
          
          should "order the negatives after the positives" do
            assert_equal "Tobias Funke", @photo.comments.last.author, "Tobias is not the last comment: #{@photo.comments.inspect}"
          end
        end
    
        context "with missing associated" do
          should "remove those children from the parent" do
            assert !@photo.comments.any? { |comment| comment.author == "Bob Loblaw" }, "Comment not included was not removed."
          end
        end
      end
      
      context "with comment_attributes = nil" do
        setup do
          @photo.save
          @photo.comment_attributes = nil
          @photo.save
        end

        should "remove all comments" do
          assert @photo.comments.empty?, "one or more comments not removed: #{@photo.comments.inspect}"
        end
      end
      
      context "with discard_if => proc { }" do
        setup do
          create_photo_with_discard(proc { |comment| comment.author.blank? && comment.body.blank? })
        end
        
        teardown do
          Photo.class_eval do
            managed_association_attributes[:comments].delete(:discard_if)
          end
        end

        should "discard any child objects for which discard_if evaluates to true" do
          assert !@photo.comments.any? { |comment| comment.author.blank? && comment.body.blank? }, @photo.comments.inspect
        end
        
        should "not discard other objects" do
          assert_equal 1, @photo.comments.length
        end
      end
      
      context "with discard_if => :symbol" do
        setup do
          create_photo_with_discard(:blank?)
        end
        
        teardown do
          Photo.class_eval do
            managed_association_attributes[:comments].delete(:discard_if)
          end
        end
        
        should "discard any child objects for which discard_if evaluates to true" do
          assert !@photo.comments.any? { |comment| comment.author.blank? && comment.body.blank? }, @photo.comments.inspect
        end
        
        should "not discard other objects" do
          assert_equal 1, @photo.comments.length
        end
      end
    end
    
    context "updating with invalid children" do
      setup do
        @photo = Photo.create
        @saved = @photo.update_attributes :comment_attributes => {:new => {"0" => {:author => "Tobias"}}}
      end
      
      should "not save" do
        assert !@saved
      end
      
      should "have errors on child" do
        assert @photo.comments.first.errors.on(:body)
      end
    end
  end
  
  private
    def create_photo_and_children
      @photo = Photo.create
      @gob = @photo.comments.create :author => "Gob Bluth",  :body => "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed..."
      @bob = @photo.comments.create :author => "Bob Loblaw", :body => "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed..."
    end
    
    def create_photo_with_discard(discard_if)
      Photo.class_eval do
        has_many :comments, :attributes => true, :discard_if => discard_if
      end
      
      create_photo_and_children
      
      
      @photo.comment_attributes = { @gob.id.to_s => { :author => "Buster Bluth", :body => "I said it was _our_ nausia..." },
                                    @bob.id.to_s => { :author => '', :body => '' },
                                    :new         => { "0" => { :author => "", :body => "" }}}
      @photo.save
    end
end
