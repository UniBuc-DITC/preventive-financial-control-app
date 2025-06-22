# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ApplicationHelper

  before_action :update_session_role
  before_action :require_login

  helper_method :current_user
  helper_method :current_year

  protected

  def current_user
    @current_user ||= User.find(session[:current_user_id])
  end

  def current_year
    @current_year ||= Setting.current_year
  end

  private

  def update_session_role
    # Nothing to fix up
    return if session[:current_user_role].blank?

    case session[:current_user_role].to_s
    when 'employee'
      new_role_name = 'Employee'
    when 'supervisor'
      new_role_name = 'Supervisor'
    when 'admin'
      new_role_name = 'Administrator'
    else
      flash[:alert] = "Rol de utilizator necunoscut: '#{session[:current_user_role]}'"
      reset_session
      return redirect_to root_path
    end

    session[:current_user_role_id] = Role.find_by!(name: new_role_name).id
    session.delete(:current_user_role)
  end

  def require_login
    return if session.key? :current_user_id

    flash[:alert] = 'Trebuie să fii autentificat pentru a putea folosi aplicația.'
    redirect_to root_path
  end

  def require_permission(permission)
    return if current_user_has_permission? permission

    flash[:alert] = "Trebuie să ai permisiunea '#{permission}' pentru a putea accesa această pagină."
    redirect_back_or_to root_path
  end
end
