# frozen_string_literal: true

class Admin::CustomerHighlightsController < Admin::BaseController
  before_action :set_customer_highlight, only: [ :edit, :update, :destroy ]

  def index
    @customer_highlights = CustomerHighlight.ordered
  end

  def new
    @customer_highlight = CustomerHighlight.new(position: next_position)
  end

  def create
    @customer_highlight = CustomerHighlight.new(customer_highlight_params)

    if @customer_highlight.save
      redirect_to admin_customer_highlights_path, notice: "Customer highlight created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @customer_highlight.update(customer_highlight_params)
      redirect_to admin_customer_highlights_path, notice: "Customer highlight updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @customer_highlight.destroy
    redirect_to admin_customer_highlights_path, notice: "Customer highlight deleted."
  end

  private

  def set_customer_highlight
    @customer_highlight = CustomerHighlight.find(params[:id])
  end

  def next_position
    (CustomerHighlight.maximum(:position) || -1) + 1
  end

  def customer_highlight_params
    params.require(:customer_highlight).permit(:customer_name, :quote, :rating, :position, :active, :photo)
  end
end
