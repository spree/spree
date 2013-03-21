require 'ostruct'

module Spree
  class Shipment < ActiveRecord::Base
    belongs_to :order

    has_many :shipping_rates
    has_many :shipping_methods, :through => :shipping_rates

    belongs_to :address
    belongs_to :stock_location

    has_many :state_changes, :as => :stateful
    has_many :inventory_units, :dependent => :destroy
    has_one :adjustment, :as => :source, :dependent => :destroy

    before_create :generate_shipment_number
    after_save :ensure_correct_adjustment, :ensure_selected_shipping_rate, :update_order

    attr_accessor :special_instructions

    attr_accessible :order, :special_instructions,
                    :tracking, :address, :inventory_units, :selected_shipping_rate_id

    accepts_nested_attributes_for :address
    accepts_nested_attributes_for :inventory_units

    make_permalink :field => :number

    scope :with_state, lambda { |s| where(:state => s) }
    scope :shipped, with_state('shipped')
    scope :ready, with_state('ready')
    scope :pending, with_state('pending')
    scope :trackable, where("spree_shipments.tracking is not null
                             and spree_shipments.tracking != ''")

    def to_param
      number if number
      generate_shipment_number unless number
      number.to_s.to_url.upcase
    end

    def backordered?
      inventory_units.any? { |iu| iu.backordered? }
    end

    def shipped=(value)
      return unless value == '1' && shipped_at.nil?
      self.shipped_at = Time.now
    end

    def shipping_method
      shipping_rates.where(selected: true).first.try(:shipping_method) || shipping_rates.first.try(:shipping_method)
    end

    def add_shipping_method(shipping_method, selected=false)
      shipping_rates << Spree::ShippingRate.create(:shipping_method => shipping_method,
                                                                        :selected => selected)
    end

    def selected_shipping_rate
      shipping_rates.where(selected: true).first
    end

    def selected_shipping_rate_id
      selected_shipping_rate.try(:id)
    end

    def selected_shipping_rate_id=(id)
      shipping_rates.update_all(selected: false)
      shipping_rates.update(id, selected: true)
      self.save!
    end

    def ensure_selected_shipping_rate
      shipping_rates.exists?(selected: true) ||
        shipping_rates.limit(1).update_all(selected: true)
    end


    def currency
      order.nil? ? Spree::Config[:currency] : order.currency
    end

    # The adjustment amount associated with this shipment (if any.)  Returns only the first adjustment to match
    # the shipment but there should never really be more than one.
    def cost
      adjustment ? adjustment.amount : 0
    end

    alias_method :amount, :cost

    def display_cost
      Spree::Money.new(cost, { :currency => currency })
    end

    alias_method :display_amount, :display_cost

    # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine :initial => 'pending', :use_transactions => false do
      event :ready do
        transition :from => 'pending', :to => 'ready', :if => lambda { |shipment|
          # Fix for #2040
          shipment.determine_state(shipment.order) == 'ready'
        }
      end

      event :pend do
        transition :from => 'ready', :to => 'pending'
      end

      event :ship do
        transition :from => 'ready', :to => 'shipped'
      end
      after_transition :to => 'shipped', :do => :after_ship

      event :cancel do
        transition :to => 'canceled'
      end
      after_transition :to => 'canceled', :do => :after_cancel
    end

    def editable_by?(user)
      !shipped?
    end

    def manifest
      inventory_units.group_by(&:variant).map do |i|
        OpenStruct.new(:variant => i.first, :quantity => i.last.length)
      end
    end

    def line_items
      if order.complete? and Spree::Config[:track_inventory_levels]
        order.line_items.select { |li| inventory_units.pluck(:variant_id).include?(li.variant_id) }
      else
        order.line_items
      end
    end

    def after_cancel
      inventory_units.each { |iu| iu.cancel! }
      # TODO stock movements
    end

    def resume(order)
      #move inventory units to canceled?
      #stock movements
      # let it create the stock movement
    end

    # Updates various aspects of the Shipment while bypassing any callbacks.  Note that this method takes an explicit reference to the
    # Order object.  This is necessary because the association actually has a stale (and unsaved) copy of the Order and so it will not
    # yield the correct results.
    def update!(order)
      old_state = state
      new_state = determine_state(order)
      update_column 'state', new_state
      after_ship if new_state == 'shipped' and old_state != 'shipped'
    end

    # Determines the appropriate +state+ according to the following logic:
    #
    # pending    unless order is complete and +order.payment_state+ is +paid+
    # shipped    if already shipped (ie. does not change the state)
    # ready      all other cases
    def determine_state(order)
      return 'pending' unless order.can_ship?
      return 'pending' if inventory_units.any? &:backordered?
      return 'shipped' if state == 'shipped'
      order.paid? ? 'ready' : 'pending'
    end

    def tracking_url
      @tracking_url ||= shipping_method.build_tracking_url(tracking)
    end

    private
      def generate_shipment_number
        return number unless number.blank?
        record = true
        while record
          random = "H#{Array.new(11) { rand(9) }.join}"
          record = self.class.where(:number => random).first
        end
        self.number = random
      end

      def description_for_shipping_charge
        "#{I18n.t(:shipping)} (#{shipping_method.name})"
      end

      def validate_shipping_method
        unless shipping_method.nil?
          errors.add :shipping_method, I18n.t(:is_not_available_to_shipment_address) unless shipping_method.include?(address)
        end
      end

      def after_ship
        inventory_units.each &:ship!
        adjustment.finalize!
        send_shipped_email
        touch :shipped_at
      end

      def send_shipped_email
        ShipmentMailer.shipped_email(self).deliver
      end

      def ensure_correct_adjustment
        if adjustment
          adjustment.originator = shipping_method
          adjustment.label = shipping_method.name
          adjustment.amount = selected_shipping_rate.cost
          adjustment.save!
      	  adjustment.reload

        elsif shipping_method
          shipping_method.create_adjustment(shipping_method.adjustment_label, order, self, true)
          reload #ensure adjustment is present on later saves
        end
      end

      def update_order
        order.update!
      end
  end
end
