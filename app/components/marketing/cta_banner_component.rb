# frozen_string_literal: true

# Full-width promotional band (e.g. "Ready for your next adventure?").
# Replaces the reference site's flattened marketing-image banners with live,
# accessible HTML carrying the same bold visual weight.
class Marketing::CtaBannerComponent < ViewComponent::Base
  TONES = {
    dark: { bg: "bg-ink-950", title: "text-white", body: "text-grey-300", button: :primary },
    light: { bg: "bg-grey-50", title: "text-ink-950", body: "text-grey-600", button: :primary }
  }.freeze

  def initialize(title:, cta_label:, cta_url:, description: nil, tone: :dark)
    raise ArgumentError, "unknown tone: #{tone.inspect}" unless TONES.key?(tone)

    @title = title
    @description = description
    @cta_label = cta_label
    @cta_url = cta_url
    @tone = TONES.fetch(tone)
  end

  attr_reader :title, :description, :cta_label, :cta_url, :tone
end
