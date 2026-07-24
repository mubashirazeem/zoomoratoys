module ApplicationHelper
  # Renders an integer cent amount (see DATABASE_GUIDELINES.md) as "AED
  # 1,234" — this catalog's price points have no fractional AED, so there's
  # no decimal handling to worry about. The single formatter for currency
  # anywhere in the app; components reach it via `helpers.format_aed`.
  def format_aed(cents)
    "AED #{number_with_thousands(cents / 100)}"
  end

  # Same currency, but keeps fils (the 2 decimal places format_aed
  # deliberately drops) — needed for the invoice's VAT breakdown, since
  # backing 5% out of a whole-dirham total routinely lands on a fractional
  # amount (e.g. AED 215.00 -> AED 204.76 excl. VAT + AED 10.24 VAT).
  def format_aed_precise(cents)
    whole, fils = cents.divmod(100)
    "AED #{number_with_thousands(whole)}.#{fils.to_s.rjust(2, '0')}"
  end

  # Hand-rolled rather than ActionView's number_with_delimiter: that helper
  # isn't reliably mixed into a ViewComponent's `helpers` proxy, while a
  # plain custom ApplicationHelper method (this one) is.
  def number_with_thousands(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end
