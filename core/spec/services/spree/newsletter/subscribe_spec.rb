require 'spec_helper'

module Spree
  describe Newselleter::Subscribe do
    subject(:service) { described_class.new(params).call }

    let(:params) do
      {
        email: email,
        user_caller: user
      }
    end

    let(:user) { create(:user) }
    let(:email) { user.email }

    context 'with user' do
      context 'when email is user.email' do
        let(:email) { user.email }

        it 'does not send a confirmation email' do
          expect { service }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end

        it 'creates a new verified subscriber' do
          expect { service }.to change { Spree::NewsletterSubscriber.verified.count }.by(1)
        end
      end

      context 'when email is not user.email' do
        let(:email) { 'test@example.com' }
        
        it 'sends a confirmation email' do
          expect { service }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end

        it 'creates a new unverified subscriber' do
          expect { service }.to change { Spree::NewsletterSubscriber.unverified.count }.by(1)
        end
      end

      context 'when subscription already exists' do
        context 'when subscription is verified' do
          let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: Time.current) }

          it 'does not create new subscriber' do
            expect { service }.not_to change { Spree::NewsletterSubscriber.count }
          end

          it 'does not regenerate verification token' do
            expect { service }.not_to change { subscriber.reload.verification_token }
          end

          it 'does not send a confirmation email' do
            expect { service }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
          end
        end

        context 'when subscription is unverified' do
          let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: nil) }

          it 'does not create new subscriber' do
            expect { service }.not_to change { Spree::NewsletterSubscriber.count }
          end

          it 'regenerates verification token' do
            expect { service }.to change { subscriber.reload.verification_token }
          end

          it 'sends a confirmation email' do
            expect { service }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
          end
        end
      end
    end

    context 'without user' do
      context 'when subscription already exists' do
        context 'when subscription is verified' do
          let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: Time.current) }

          it 'does not create new subscriber' do
            expect { service }.not_to change { Spree::NewsletterSubscriber.count }
          end

          it 'does not regenerate verification token' do
            expect { service }.not_to change { subscriber.reload.verification_token }
          end

          it 'does not send a confirmation email' do
            expect { service }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
          end
        end

        context 'when subscription is unverified' do
          let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: nil) }

          it 'does not create new subscriber' do
            expect { service }.not_to change { Spree::NewsletterSubscriber.count }
          end

          it 'regenerates verification token' do
            expect { service }.to change { subscriber.reload.verification_token }
          end

          it 'sends a confirmation email' do
            expect { service }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
          end
        end
      end

      context 'when subscription does not exist' do
        it 'creates a new unverified subscriber' do
          expect { service }.to change { Spree::NewsletterSubscriber.unverified.count }.by(1)
        end

        it 'sends a confirmation email' do
          expect { service }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end
    end
  end
end