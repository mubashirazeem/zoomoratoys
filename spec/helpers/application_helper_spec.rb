require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#display_currency" do
    it "defaults to AED when no currency cookie is set" do
      expect(helper.display_currency).to eq("AED")
    end

    it "reads USD from the cookie" do
      cookies[:currency] = "USD"

      expect(helper.display_currency).to eq("USD")
    end

    it "falls back to AED for a tampered/unrecognized cookie value" do
      cookies[:currency] = "GBP"

      expect(helper.display_currency).to eq("AED")
    end

    it "falls back to AED for an empty cookie value" do
      cookies[:currency] = ""

      expect(helper.display_currency).to eq("AED")
    end

    it "falls back to AED for a script-injection attempt in the cookie — never rendered raw, but should still be handled like any other unrecognized value" do
      cookies[:currency] = "<script>alert(1)</script>"

      expect(helper.display_currency).to eq("AED")
    end

    it "is case-sensitive — lowercase 'usd' is not the same as 'USD' and falls back to AED" do
      cookies[:currency] = "usd"

      expect(helper.display_currency).to eq("AED")
    end
  end

  describe "#format_price" do
    it "renders whole AED, same as format_aed, when the display currency is AED" do
      expect(helper.format_price(60_000)).to eq(helper.format_aed(60_000))
    end

    it "converts to USD with two decimals using the current exchange rate" do
      allow(ExchangeRate).to receive(:current_usd_per_aed).and_return(BigDecimal("0.272294"))
      cookies[:currency] = "USD"

      expect(helper.format_price(60_000)).to eq("$163.38 USD")
    end

    it "renders zero cleanly" do
      allow(ExchangeRate).to receive(:current_usd_per_aed).and_return(BigDecimal("0.272294"))
      cookies[:currency] = "USD"

      expect(helper.format_price(0)).to eq("$0.00 USD")
    end

    it "handles the smallest possible amount (1 AED cent) without rounding to nothing" do
      allow(ExchangeRate).to receive(:current_usd_per_aed).and_return(BigDecimal("0.272294"))
      cookies[:currency] = "USD"

      expect(helper.format_price(1)).to eq("$0.00 USD")
    end

    it "adds thousands separators to a large converted amount" do
      allow(ExchangeRate).to receive(:current_usd_per_aed).and_return(BigDecimal("0.272294"))
      cookies[:currency] = "USD"

      # AED 50,000 (5,000,000 cents) -> $13,614.70
      expect(helper.format_price(5_000_000)).to eq("$13,614.70 USD")
    end
  end

  describe "#json_ld_script_tag" do
    it "escapes a literal </script> in a data value so it can't break out of the surrounding script tag" do
      output = helper.json_ld_script_tag(description: "malicious </script><script>alert(1)</script> payload")

      expect(output).not_to include("</script><script>")
      # The only literal "</script>" anywhere in the rendered tag is its own
      # real closing tag, appended by content_tag at the very end — none of
      # it leaks through from the data value itself, so a description
      # containing that sequence can't prematurely terminate the wrapping
      # <script> element.
      expect(output.scan("</script>").size).to eq(1)
      expect(output).to end_with("</script>")
    end
  end
end
