# frozen_string_literal: true

# Backs the real "N customers are viewing this product" count on the product
# page. viewer_token is the visitor's session id — no login required, no
# personally-identifying data stored beyond what Rails' session cookie
# already implies.
class ProductView < ApplicationRecord
  belongs_to :product

  validates :viewer_token, presence: true

  CURRENT_WINDOW = 10.minutes

  # One row per (product, viewer) ever, "viewing now" tracked by touching
  # updated_at — not one row per window, so a persistent viewer doesn't
  # accumulate a new row every ten minutes forever. Idempotent even under
  # genuine concurrency (two simultaneous requests from the same visitor):
  # the real unique index on (product_id, viewer_token) is what actually
  # prevents the double-insert a plain check-then-create can't, under a
  # race a check-then-create alone can't close — the retry lands on the
  # row the other request just committed.
  def self.record!(product:, viewer_token:)
    view = find_by(product: product, viewer_token: viewer_token)
    return if view && view.updated_at > CURRENT_WINDOW.ago

    view ? view.touch : create!(product: product, viewer_token: viewer_token)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.current_count_for(product)
    where(product: product, updated_at: CURRENT_WINDOW.ago..).distinct.count(:viewer_token)
  end
end
