# frozen_string_literal: true

# Every button/button-styled-link in the app renders through here so hover,
# focus, and disabled states stay identical everywhere. Renders an <a> when
# `href` is given (navigation), otherwise a real <button> (actions/forms).
class Ui::ButtonComponent < ViewComponent::Base
  VARIANT_CLASSES = {
    primary: "bg-red-600 text-white hover:bg-red-700 active:bg-red-800",
    secondary: "bg-ink-950 text-white hover:bg-ink-800 active:bg-ink-700",
    ghost: "bg-transparent text-ink-950 border border-grey-300 hover:bg-grey-50 active:bg-grey-100"
  }.freeze

  # base padding/size matches rafplay's measured primary CTA exactly:
  # 13px 15px padding, 14px/700 text. sm/lg scale proportionally from that
  # anchor since the reference site doesn't expose distinct button sizes.
  SIZE_CLASSES = {
    sm: "px-[12px] py-[10px] text-[12px] font-bold",
    base: "px-[15px] py-[13px] text-[14px] font-bold",
    lg: "px-[20px] py-[16px] text-[16px] font-bold"
  }.freeze

  def initialize(variant: :primary, size: :base, href: nil, type: "button", disabled: false, full_width: false, title: nil)
    raise ArgumentError, "unknown button variant: #{variant.inspect}" unless VARIANT_CLASSES.key?(variant)
    raise ArgumentError, "unknown button size: #{size.inspect}" unless SIZE_CLASSES.key?(size)

    @variant = variant
    @size = size
    @href = href
    @type = type
    @disabled = disabled
    @full_width = full_width
    @title = title
  end

  def link?
    @href.present?
  end

  def classes
    [
      "inline-flex items-center justify-center gap-2 rounded-md font-display transition-colors duration-150",
      "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600",
      VARIANT_CLASSES.fetch(@variant),
      SIZE_CLASSES.fetch(@size),
      (@full_width ? "w-full" : nil),
      (@disabled ? "opacity-50 cursor-not-allowed pointer-events-none" : nil)
    ].compact.join(" ")
  end

  attr_reader :href, :type, :disabled, :title
end
