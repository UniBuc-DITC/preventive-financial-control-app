# frozen_string_literal: true

class ProjectCategoriesController < ApplicationController
  before_action -> { require_permission 'ProjectCategory.View' }, only: %i[index]
  before_action -> { require_permission 'ProjectCategory.Create' }, only: %i[new create]
  before_action -> { require_permission 'ProjectCategory.Edit' }, only: %i[edit update]
  before_action -> { require_permission 'ProjectCategory.Delete' }, only: %i[destroy]

  def index
    @project_categories = ProjectCategory.order(name: :asc)
  end

  def new
    @project_category = ProjectCategory.new
  end

  def edit
    project_category_id = params.require(:id)
    @project_category = ProjectCategory.find(project_category_id)
  end

  def create
    @project_category = ProjectCategory.new project_category_params

    successfully_saved = false
    ProjectCategory.transaction do
      successfully_saved = @project_category.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :project_categories,
          target_object_id: @project_category.id
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost salvată cu succes o nouă categorie de proiect cu denumirea '#{@project_category.name}'"
      redirect_to project_categories_path
    else
      flash[:alert] = 'Nu s-a putut salva noua categorie de proiect. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    project_category_id = params.require(:id)
    @project_category = ProjectCategory.find(project_category_id)

    @project_category.assign_attributes project_category_params

    successfully_saved = false
    ProjectCategory.transaction do
      successfully_saved = @project_category.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :project_categories,
          target_object_id: @project_category.id
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost actualizată cu succes categoria de proiect cu denumirea '#{@project_category.name}'"
      redirect_to project_categories_path
    else
      flash[:alert] =
        'Nu s-au putut salva modificările la categoria de proiect. Verificați erorile și încercați din nou.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    project_category_id = params.require(:id)
    @project_category = ProjectCategory.find(project_category_id)

    successfully_deleted = false
    ProjectCategory.transaction do
      successfully_deleted = @project_category.destroy

      if successfully_deleted
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :delete,
          target_table: :project_categories,
          target_object_id: @project_category.id
        )
      end
    end

    if successfully_deleted
      flash[:notice] = "A fost ștearsă cu succes categoria de proiect cu denumirea '#{@project_category.name}'"
    else
      flash[:alert] = "Nu s-a putut șterge categoria de proiect: #{@project_category.errors.full_messages.join(', ')}."
    end

    redirect_to project_categories_path
  end

  private

  def project_category_params
    params.require(:project_category).permit(:name, :import_code)
  end
end
