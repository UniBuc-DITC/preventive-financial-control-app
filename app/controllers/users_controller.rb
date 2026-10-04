# frozen_string_literal: true

class UsersController < ApplicationController
  before_action -> { require_permission 'User.View' }, only: %i[index]
  before_action -> { require_permission 'User.Create' }, only: %i[new create]
  before_action -> { require_permission 'User.Edit' }, only: %i[edit update]

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
      flash.now[:alert] = 'Nu se poate crea un nou utilizator fără ID-ul din Microsoft Entra.'
      return render :new
    end

    client = MicrosoftGraphClient.new

    begin
      result = client.get_user_by_id(@user.entra_user_id)
      raise StandardError.new, 'not found' if result.nil?

      @user.email = result['mail']
      @user.first_name = result['givenName']
      @user.last_name = result['surname']
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

    new_attributes = user_params

    new_attributes.delete :role if current_user == @user

    @user.assign_attributes new_attributes

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
    params.expect(user: %i[entra_user_id role_id background_color text_color])
  end
end
