# frozen_string_literal: true

# A single collapsible row built on the native <details>/<summary> element
# (no JS needed, keyboard-accessible for free). The body is provided via a
# slot so callers can pass tables, lists, or prose.
class Ui::AccordionItemComponent < ViewComponent::Base
  renders_one :body

  def initialize(title:, open: false)
    @title = title
    @open = open
  end

  attr_reader :title, :open
end
