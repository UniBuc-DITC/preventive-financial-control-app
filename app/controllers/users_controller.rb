# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :require_supervisor_or_admin, only: %i[new edit create update]

  def index
    @users = User.order(:id).all
  end

  def new
    @user = User.new
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new user_params

    if @user.entra_user_id.blank?
      flash[:alert] = 'Nu se poate crea un nou utilizator fără ID-ul din Microsoft Entra.'
      return render :new
    end

    client = microsoft_graph_client

    begin
      result = client.users.by_user_id(@user.entra_user_id).get.resume

      @user.email = result.mail
      @user.first_name = result.given_name
      @user.last_name = result.surname
    rescue StandardError
      @user.errors.add :entra_user_id, 'nu a fost găsit în tenant'
      return render :new, status: :unprocessable_entity
    end

    successfully_saved = false
    User.transaction do
      successfully_saved = @user.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :users,
          target_object_id: @user.id
        )
      end
    end

    if successfully_saved
      flash[:notice] = 'Utilizatorul a fost adăugat cu succes.'
      redirect_to users_path
    else
      flash[:alert] = 'Nu s-a putut salva noul utilizator.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    user_id = params.require(:id)
    @user = User.find(user_id)

    # No user can change their own role.
    render status :bad_request if @user.id == current_user.id
    # Supervisors cannot change the role of an admin.
    render status: :unauthorized if current_user.supervisor? && @user.admin?
    render status: :unauthorized unless params[:user][:role].in? helpers.selectable_roles

    @user.assign_attributes user_params

    successfully_saved = false
    User.transaction do
      successfully_saved = @user.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :users,
          target_object_id: @user.id
        )
      end
    end

    if successfully_saved
      flash[:notice] = 'Utilizatorul a fost modificat cu succes.'
      redirect_to users_path
    else
      flash[:alert] = 'Nu s-au putut salva modificările la noul utilizator.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:entra_user_id, :role)
  end

  def microsoft_graph_client
    return @client if @client.present?

    identity_platform_credentials = Rails.application.credentials.microsoft_identity_platform

    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      identity_platform_credentials[:tenant_id],
      identity_platform_credentials[:client_id],
      identity_platform_credentials[:client_secret]
    )

    authentication_provider = MicrosoftGraphCore::Authentication::OAuthAuthenticationProvider.new(
      context,
      nil,
      ['https://graph.microsoft.com/.default']
    )

    adapter = MicrosoftGraph::GraphRequestAdapter.new(authentication_provider)
    client = MicrosoftGraph::GraphServiceClient.new(adapter)

    @client = client

    client
  end
end
