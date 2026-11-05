# frozen_string_literal: true

require 'spec_helper'

# Every registered customer email asks the store whether to send it, so an
# integration that takes one over (Spree::Integration#replaced_customer_emails)
# actually stops it. A new customer email fails here until it has a trigger.
# Nothing in Spree sends the payment link email.
UNSENT_CUSTOMER_EMAILS = ['spree/order_mailer/payment_link_email'].freeze

RSpec.describe 'Customer email templates taken over by an integration' do
  let(:store) { @default_store }

  let(:replacing_class) do
    Class.new(Spree::Integration) do
      def self.name = 'TestIntegrations::EmailSender'

      preference :replaced, :array, of: :string, default: []

      def replaced_customer_emails = preferred_replaced
    end
  end

  def event(payload, metadata = {})
    double('Event', payload: payload, metadata: metadata)
  end

  def completed_order
    create(:completed_order_with_totals, store: store)
  end

  def order_with_downloads
    completed_order.tap do |order|
      line_item = order.line_items.first
      create(:digital_link, digital_asset: create(:digital_asset, variant: line_item.variant), line_item: line_item)
    end
  end

  def refunded_return
    create(:received_return, store: store).tap { |record| create(:store_credit, originator: record, amount: 10) }
  end

  def finished_access_request
    create(:data_request, store: store, customer: create(:user)).tap do |data_request|
      Spree::DataRequests::Fulfill.call(data_request: data_request)
    end.reload
  end

  # Template key => the ways Spree sends that email, each a lambda delivering it once.
  let(:triggers) do
    {
      'spree/order_mailer/confirm_email' => {
        'order.placed' => -> { Spree::OrderEmailSubscriber.new.send(:send_confirmation_email, event('id' => completed_order.prefixed_id)) },
        'order.resend_confirmation_email' => -> { Spree::OrderEmailSubscriber.new.send(:resend_confirmation_email, event('id' => completed_order.prefixed_id)) }
      },
      'spree/order_mailer/cancel_email' => {
        'order.canceled' => -> { Spree::OrderEmailSubscriber.new.send(:send_cancel_email, event('id' => completed_order.prefixed_id)) }
      },
      'spree/order_group_mailer/confirm_email' => {
        'order_group.completed' => lambda {
          Spree::OrderGroupEmailSubscriber.new.send(:send_confirmation_email, event('id' => create(:order_group, store: store).prefixed_id))
        },
        'order_group.resend_confirmation_email' => -> { Spree::OrderGroupEmailSubscriber.new.send(:resend_confirmation_email, event('id' => create(:order_group, store: store).prefixed_id)) }
      },
      'spree/fulfillment_mailer/fulfilled_email' => {
        'fulfillment.fulfilled' => -> { Spree::FulfillmentEmailSubscriber.new.handle(event('id' => completed_order.fulfillments.first.prefixed_id)) }
      },
      'spree/return_mailer/refunded_email' => {
        'return.refunded' => -> { Spree::ReturnEmailSubscriber.new.handle(event('id' => refunded_return.prefixed_id)) }
      },
      'spree/digital_asset_mailer/files_ready_email' => {
        'order.placed' => lambda {
          Spree::DigitalAssetEmailSubscriber.new.send(:send_files_ready_email, event('id' => order_with_downloads.prefixed_id))
        },
        'order.resend_digital_links_email' => -> { Spree::DigitalAssetEmailSubscriber.new.send(:resend_files_ready_email, event('id' => order_with_downloads.prefixed_id)) }
      },
      'spree/customer_mailer/password_reset_email' => {
        'customer.password_reset_requested' => lambda {
          Spree::CustomerEmailSubscriber.new.handle(
            event('email' => create(:user).email, 'reset_token' => 'token', 'store_id' => store.prefixed_id)
          )
        }
      },
      'spree/customer_mailer/data_export_email' => {
        'data_request.completed' => -> { Spree::DataRequestEmailSubscriber.new.handle(event('id' => finished_access_request.prefixed_id)) }
      },
      'spree/customer_mailer/data_request_confirmation_email' => {
        'data_request.confirmation_requested' => lambda {
          data_request = create(:data_request, :awaiting_confirmation, store: store, customer: create(:user))
          Spree::DataRequestConfirmationEmailSubscriber.new.handle(event('id' => data_request.prefixed_id, 'confirmation_token' => 'token'))
        }
      },
      'spree/newsletter_mailer/email_confirmation' => {
        'newsletter_subscriber.subscription_requested' => lambda {
          Spree::NewsletterSubscriberEmailSubscriber.new.handle(event('id' => create(:newsletter_subscriber, store: store).prefixed_id))
        }
      },
      'spree/company_mailer/invitation_email' => {
        'company_invitation.created' => lambda {
          invitation = create(:company_invitation, company: create(:company, store: store))
          Spree::CompanyEmailSubscriber.new.handle(event('id' => invitation.prefixed_id))
        }
      }
    }
  end

  let(:registered_keys) { Spree.editable_email_templates.emails.map(&:key) - UNSENT_CUSTOMER_EMAILS }

  before do
    stub_const('TestIntegrations::EmailSender', replacing_class)
    allow(Spree).to receive(:integrations).and_return(['TestIntegrations::EmailSender'])
    # Subscribers reload the store, so the predicate is stubbed on every instance.
    allow_any_instance_of(Spree::Store).to receive(:prefers_send_consumer_transactional_emails?).and_return(true)
  end

  it 'has a trigger for every registered customer email' do
    expect(triggers.keys).to match_array(registered_keys)
  end

  Spree.editable_email_templates.emails.map(&:key).each do |template_key|
    next if UNSENT_CUSTOMER_EMAILS.include?(template_key)

    mailer = File.dirname(template_key).camelize.constantize
    mail_method = File.basename(template_key)

    describe template_key do
      it 'has at least one trigger' do
        expect(triggers.fetch(template_key)).not_to be_empty
      end

      it 'is sent while no integration takes it over' do
        triggers.fetch(template_key).each_value do |deliver|
          expect { deliver.call }.to have_enqueued_mail(mailer, mail_method)
        end
      end

      it 'is not sent while an active integration takes it over' do
        TestIntegrations::EmailSender.create!(store: store, active: true, preferred_replaced: [template_key])

        triggers.fetch(template_key).each_value do |deliver|
          expect { deliver.call }.not_to have_enqueued_mail(mailer, mail_method)
        end
      end
    end
  end
end
