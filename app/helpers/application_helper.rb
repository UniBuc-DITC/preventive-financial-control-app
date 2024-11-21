# frozen_string_literal: true

module ApplicationHelper
  def current_user_role
    session[:current_user_role]
  end

  def current_user_is_supervisor_or_admin?
    current_user_role == 'supervisor' || current_user_role == 'admin'
  end
end
