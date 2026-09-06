module Payments
  module Tamara
    # Tamara's own docs call this "a mandatory step in the checkout flow —
    # not optional," to be called before even showing Tamara as a payment
    # option: some customers (decline history) should never see the button
    # at all. Per Tamara's own guidance, this uses a short (200ms) timeout
    # and defaults to eligible — i.e. show Tamara as normal — on any
    # failure or timeout, so a slow/unavailable eligibility check degrades
    # to today's behavior instead of breaking checkout page rendering.
    #
    # phone_number is deliberately omitted — it's optional per Tamara's
    # spec ("if omitted, customer is treated as eligible"), and at
    # checkout#show time there's no single phone number to send yet (the
    # customer hasn't picked/entered a shipping address on this page).
    class CheckEligibility
      TIMEOUT_SECONDS = 0.2

      def self.call(amount_cents:, email:)
        new(amount_cents: amount_cents, email: email).call
      end

      def initialize(amount_cents:, email:)
        @amount_cents = amount_cents
        @email = email
      end

      def call
        response = Payments::Tamara.post("/pre-checkout/v1/eligibility", {
          # order.amount must be a JSON number, not a string — sending it
          # quoted made Tamara reject the whole request as "invalid json"
          # (confirmed empirically against the real sandbox; a bug that
          # was invisible for months because the account wasn't even
          # activated yet, so every prior call had already failed before
          # this schema mismatch could matter).
          order: { amount: (@amount_cents / 100.0).round(2), currency: "AED" },
          customer: { email: @email }
        }, timeout: TIMEOUT_SECONDS)

        response.fetch("is_eligible", true)
      rescue Payments::ProviderError
        true
      end
    end
  end
end
