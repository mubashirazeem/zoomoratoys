# frozen_string_literal: true

# Owner-only: invite new admins, see who has access, change someone's role,
# or deactivate them. See Admin::BaseController#require_owner! and
# AdminUser's active_for_authentication? override (that's what actually
# enforces deactivation — this controller only flips the flag).
class Admin::AdminUsersController < Admin::BaseController
  before_action :require_owner!
  before_action :set_admin_user, only: [ :edit, :update ]

  def index
    @admin_users = AdminUser.order(:name)
  end

  def new
    @admin_user = AdminUser.new
  end

  def create
    @admin_user = AdminUser.invite!(admin_user_params, current_admin_user)

    if @admin_user.errors.empty?
      redirect_to admin_admin_users_path, notice: "Invitation sent to #{@admin_user.email}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @admin_user == current_admin_user
      redirect_to admin_admin_users_path, alert: "You can't change your own role or access — ask another owner to do it."
      return
    end

    if @admin_user.update(admin_user_update_params)
      redirect_to admin_admin_users_path, notice: "#{@admin_user.name}'s access updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_admin_user
    @admin_user = AdminUser.find(params[:id])
  end

  # :invite! only ever creates a record — role/active on that first form
  # are safe to accept directly (an editing Owner already handles the
  # self-edit guard separately in #update).
  def admin_user_params
    params.require(:admin_user).permit(:name, :email, :role)
  end

  def admin_user_update_params
    params.require(:admin_user).permit(:role, :active)
  end
end
