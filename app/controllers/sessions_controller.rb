# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    user_info = request.env['omniauth.auth']

    provider = user_info['provider']&.to_sym
    if provider == :microsoft_identity_platform
      user = User.find_by(entra_user_id: user_info['uid'])

      if user.nil?
        flash[:alert] = 'Nu vă puteți conecta deoarece contul dvs. nu are drept de acces în aplicație. ' \
                        'Rugați un administrator să vă adauge contul.'
      else
        session[:current_user_id] = user.id
        session[:current_user_role_id] = user.role_id
        session[:current_user_full_name] = user.full_name

        flash[:notice] = 'Autentificat cu succes.'
      end
    elsif provider == :developer && Rails.env.local?
      payload = user_info['info']
      email = payload['email']
      first_name = payload['first_name']
      last_name = payload['last_name']
      full_name = "#{first_name} #{last_name}"
      role = Role.find_by(name: payload['role'] || 'Employee')
      raise StandardError.new, "Nonexistent role: '#{payload['role']}'" if role.nil?

      id = Digest::SHA2.hexdigest(full_name)
      session[:current_user_role_id] = role.id
      session[:current_user_full_name] = full_name

      user = User.find_or_initialize_by(entra_user_id: id)
      unless user.persisted?
        user.role = role
        user.email = email
        user.first_name = first_name
        user.last_name = last_name
        user.save!
      end

      session[:current_user_id] = user.id

      flash[:notice] = 'Autentificat cu succes.'
    else
      raise ActionController::BadRequest.new, "Unsupported authentication provider: '#{provider}'"
    end

    redirect_to root_path
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end
