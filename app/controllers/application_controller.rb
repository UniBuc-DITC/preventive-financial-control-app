# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :require_login

  protected

  def current_user
    @current_user ||= User.find(session[:current_user_id])
  end

  private

  def require_login
    return if session.key? :current_user_id

    flash[:alert] = 'Trebuie să fii autentificat pentru a putea folosi aplicația.'
    redirect_to root_path
  end

  def require_admin
    return if session[:current_user_role] == 'admin'

    flash[:alert] = 'Trebuie să fii administrator pentru a putea accesa această pagină.'
    redirect_back_or_to root_path
  end
end
