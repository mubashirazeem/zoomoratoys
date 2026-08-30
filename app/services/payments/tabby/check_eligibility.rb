module Payments
  module Tabby
    # Tabby's own "background pre-scoring": call the same POST
    # /api/v2/checkout endpoint used for real sessions, but with a minimal
    # payload, purely to decide whether Tabby should be shown as a
    # selectable payment method at all — before the customer ever reaches
    # Place Order. A "rejected" response here means what it means at real
    # session-creation time too (see SessionBuilder): hide/disable the
    # option and surface the same rejection message, never log it as a
    # failure.
    #
    # Same graceful-degradation shape as Payments::Tamara::CheckEligibility:
    # a short timeout, and anything short of an explicit reject — no phone
    # on file yet, a slow/unavailable Tabby, a malformed response — leaves
    # Tabby showing normally rather than breaking checkout rendering or
    # hiding it from someone who might actually be eligible.
    class CheckEligibility
      TIMEOUT_SECONDS = 0.4

      def self.call(amount_cents:, email:, phone:)
        new(amount_cents: amount_cents, email: email, phone: phone).call
      end

      def initialize(amount_cents:, email:, phone:)
        @amount_cents = amount_cents
        @email = email
        @phone = phone
      end

      # nil == show Tabby normally. A String == the rejection message to
      # show instead, per Tabby's checklist ("hide Tabby or mark it
      # unavailable with the rejection message").
      def call
        return nil if @phone.blank?

        response = Payments::Tabby.post("/api/v2/checkout", {
          payment: {
            amount: format("%.2f", @amount_cents / 100.0),
            currency: "AED",
            buyer: { email: @email, phone: @phone }
          },
          merchant_code: ENV.fetch("TABBY_MERCHANT_CODE")
        }, timeout: TIMEOUT_SECONDS)

        return nil unless response["status"] == "rejected"

        SessionBuilder.rejection_message(response)
      rescue Payments::ProviderError
        nil
      end
    end
  end
end
