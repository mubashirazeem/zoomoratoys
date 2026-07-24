# frozen_string_literal: true

# Consistent title/subtitle/action-button header for every admin page.
class Admin::PageHeaderComponent < ViewComponent::Base
  renders_one :action

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end

  attr_reader :title, :subtitle
end
