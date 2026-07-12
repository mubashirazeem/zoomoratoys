# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :comment, presence: true
  validates :user_id, uniqueness: { scope: :product_id, message: "have already reviewed this product" }

  scope :newest_first, -> { order(created_at: :desc) }
end
