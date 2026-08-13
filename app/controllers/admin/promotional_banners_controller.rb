# frozen_string_literal: true

class Admin::PromotionalBannersController < Admin::BaseController
  before_action :set_promotional_banner, only: [ :edit, :update, :destroy ]

  def index
    @promotional_banners = PromotionalBanner.ordered
  end

  def new
    @promotional_banner = PromotionalBanner.new(position: next_position)
  end

  def create
    @promotional_banner = PromotionalBanner.new(promotional_banner_params)

    if @promotional_banner.save
      redirect_to admin_promotional_banners_path, notice: "Banner created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @promotional_banner.update(promotional_banner_params)
      redirect_to admin_promotional_banners_path, notice: "Banner updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @promotional_banner.destroy
    redirect_to admin_promotional_banners_path, notice: "Banner deleted."
  end

  private

  def set_promotional_banner
    @promotional_banner = PromotionalBanner.find(params[:id])
  end

  def next_position
    (PromotionalBanner.maximum(:position) || -1) + 1
  end

  def promotional_banner_params
    params.require(:promotional_banner).permit(:title, :description, :cta_label, :cta_url, :position, :active, :image, :placement)
  end
end
