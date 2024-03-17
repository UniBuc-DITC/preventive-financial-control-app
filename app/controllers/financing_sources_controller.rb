# frozen_string_literal: true

class FinancingSourcesController < ApplicationController
  before_action :require_supervisor_or_admin, only: %i[new edit create update destroy]

  def index
    @financing_sources = FinancingSource.order(name: :asc)
  end

  def new
    @financing_source = FinancingSource.new
  end

  def edit
    financing_source_id = params.require(:id)
    @financing_source = FinancingSource.find(financing_source_id)
  end

  def create
    @financing_source = FinancingSource.new financing_source_params

    successfully_saved = false
    FinancingSource.transaction do
      successfully_saved = @financing_source.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :financing_sources,
          target_object_id: @financing_source.id,
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost salvată cu succes o nouă sursă de finanțare cu denumirea '#{@financing_source.name}'"
      redirect_to financing_sources_path
    else
      flash[:alert] = 'Nu s-a putut salva noua sursă de finanțare. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    financing_source_id = params.require(:id)
    @financing_source = FinancingSource.find(financing_source_id)

    @financing_source.assign_attributes financing_source_params

    successfully_saved = false
    FinancingSource.transaction do
      successfully_saved = @financing_source.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :financing_sources,
          target_object_id: @financing_source.id,
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost actualizată cu succes sursa de finanțare cu denumirea '#{@financing_source.name}'"
      redirect_to financing_sources_path
    else
      flash[:alert] = 'Nu s-au putut salva modificările la sursa de finanțare. Verificați erorile și încercați din nou.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    financing_source_id = params.require(:id)
    @financing_source = FinancingSource.find(financing_source_id)

    successfully_deleted = false
    FinancingSource.transaction do
      successfully_deleted = @financing_source.destroy

      if successfully_deleted
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :delete,
          target_table: :financing_sources,
          target_object_id: @financing_source.id,
        )
      end
    end

    if successfully_deleted
      flash[:notice] = "A fost ștearsă cu succes sursa de finanțare cu denumirea '#{@financing_source.name}'"
    else
      flash[:alert] = "Nu s-a putut șterge sursa de finanțare: #{@financing_source.errors.full_messages.join(', ')}."
    end

    redirect_to financing_sources_path
  end

  private

  def financing_source_params
    params.require(:financing_source).permit(:name)
  end
end
