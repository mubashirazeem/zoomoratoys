# frozen_string_literal: true

class AddressesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_address, only: [ :edit, :update, :destroy ]

  def index
    @addresses = current_user.addresses.ordered
  end

  def new
    @address = current_user.addresses.new
  end

  def create
    first_address = current_user.addresses.none?
    @address = current_user.addresses.new(address_params)
    @address.default_address = true if first_address

    if @address.save
      redirect_to addresses_path, notice: "Address saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @address.update(address_params)
      redirect_to addresses_path, notice: "Address updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @address.destroy
    redirect_to addresses_path, notice: "Address removed."
  end

  private

  def set_address
    @address = current_user.addresses.find(params[:id])
  end

  def address_params
    params.require(:address).permit(
      :label, :full_name, :phone, :address_line1, :address_line2,
      :city, :emirate, :default_address
    )
  end
end
