module Spree
  # Finds the rows that belong to one person across the tables that record an
  # email without owning a customer.
  #
  # Shared by the access export and the erasure workflow so the two cannot
  # disagree about which rows are about this person — an address one of them
  # reaches and the other does not is either data disclosed but not erased, or
  # erased but never disclosed.
  #
  # Matching is case-insensitive because the models disagree: a customer's and
  # an order's address keeps the casing it was typed in, while a newsletter
  # address is stored downcased. Someone who checks out as `Ada@Example.com`
  # and subscribes as `ada@example.com` is one person, and an exact comparison
  # would leave the guest checkout behind — still holding their name, street
  # and IP address — after they asked to be forgotten.
  module PersonalDataMatching
    extend ActiveSupport::Concern

    private

    # Rows of `model` owned by this customer, plus the ones left behind by a
    # guest checkout: someone who ordered as a guest and registered afterwards
    # has purchases carrying their address and IP with a null customer.
    #
    # @param model [Class] an ActiveRecord class with `customer_id` and `email`
    # @param email [String] the address to match, before any redaction
    # @param customer_id [String, Integer]
    # @return [ActiveRecord::Relation]
    def rows_about_person(model, email:, customer_id:)
      model.where(customer_id: customer_id).
        or(with_email(model, email).where(customer_id: nil))
    end

    # Rows of `model` whose `email` is this address, whatever its casing.
    #
    # @param model [Class]
    # @param email [String]
    # @return [ActiveRecord::Relation]
    def with_email(model, email)
      model.where(model.arel_table[:email].lower.eq(email.to_s.downcase))
    end

    # Rows at this address that no *other* person already owns.
    #
    # Consent given before an account existed is owned by nothing, or by the
    # order it was given during — both are this person's. A row owned by a
    # different customer is theirs, however the address now reads: addresses
    # get reused, and someone signing up at a colleague's old one must not
    # inherit their consent history or be able to erase it.
    #
    # @param model [Class] an ActiveRecord class with a polymorphic `owner`
    # @param email [String]
    # @param customer_type [String] the owner type that denotes an account
    # @param customer_id [String, Integer]
    # @return [ActiveRecord::Relation]
    def with_email_not_owned_by_others(model, email, customer_type:, customer_id:)
      with_email(model, email).
        where.not(owner_type: customer_type).
        or(with_email(model, email).where(owner_type: customer_type, owner_id: customer_id)).
        or(with_email(model, email).where(owner_type: nil))
    end
  end
end
