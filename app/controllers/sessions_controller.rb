# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    user_info = request.env['omniauth.auth']

    provider = user_info['provider']
    if provider == :microsoft_identity_platform
      user = User.find_by(entra_user_id: user_info['uid'])

      if user.nil?
        flash[:alert] = 'Nu vă puteți conecta deoarece contul dvs. nu are drept de acces în aplicație. ' \
          'Rugați un administrator să vă adauge contul.'
      else
        session[:current_user_id] = user.id
        session[:current_user_role] = user.role
        session[:current_user_full_name] = user.full_name

        flash[:notice] = 'Autentificat cu succes.'
      end

      return redirect_to root_path
    end

    raise ActionController::BadRequest.new
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end
