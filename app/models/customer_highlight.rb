# frozen_string_literal: true

# Admin-curated customer spotlight for the home page — a real delivered-
# product photo (optional) plus a short quote and star rating, entered by
# an admin (from Google Reviews, WhatsApp, etc.), not submitted by the
# customer themselves. Deliberately separate from Review (which is always
# customer-authored, tied to a specific product and user account) — this
# exists purely as curated marketing content (client feedback, 2026-08-13:
# "put a section here for happy customers... images of delivered products
# and google reviews").
class CustomerHighlight < ApplicationRecord
  include ImageAttachmentValidatable

  has_paper_trail

  has_one_attached :photo

  validates :customer_name, presence: true
  validates :quote, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates_image_attachment :photo

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }
end
