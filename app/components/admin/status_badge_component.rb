# frozen_string_literal: true

# A small pill badge for real status values (stock status, order status,
# coupon active/inactive, blog published/scheduled...) — the caller maps
# its own real status to a tone, this just renders it consistently.
class Admin::StatusBadgeComponent < ViewComponent::Base
  # Site-wide color rule: black/red/white/grey only, no other hues — see
  # DESIGN_SYSTEM.md. "attention" is a bordered/lighter red, not a new color.
  TONES = {
    positive: "bg-red-600/10 text-red-600",
    neutral: "bg-grey-100 text-grey-600",
    attention: "bg-white border border-red-300 text-red-600",
    negative: "bg-grey-200 text-grey-500"
  }.freeze

  def initialize(label:, tone: :neutral)
    @label = label
    @tone = tone
  end

  attr_reader :label

  def tone_classes
    TONES.fetch(@tone, TONES[:neutral])
  end
end
