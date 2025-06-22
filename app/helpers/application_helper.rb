# frozen_string_literal: true

module ApplicationHelper
  def current_user_full_name
    @current_user_full_name ||= session[:current_user_full_name]
  end

  def current_user_role
    @current_user_role ||= Role.find(session[:current_user_role_id])
  end

  def current_user_permissions
    @current_user_permissions ||= current_user_role.permissions.pluck(:name).to_set
  end

  def current_user_has_permission?(permission)
    current_user_permissions.include?(permission)
  end
end
