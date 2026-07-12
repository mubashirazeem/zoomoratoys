# frozen_string_literal: true

class ReviewsController < ApplicationController
  before_action :authenticate_user!

  def create
    product = Product.find_by!(slug: params[:product_slug])
    review = product.reviews.build(review_params.merge(user: current_user))

    if review.save
      redirect_to product_path(product), notice: "Thanks — your review has been posted."
    else
      redirect_to product_path(product), alert: review.errors.full_messages.to_sentence
    end
  end

  private

  def review_params
    params.require(:review).permit(:rating, :comment)
  end
end
