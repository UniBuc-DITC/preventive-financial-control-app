# frozen_string_literal: true

class FinancingSourcesController < ApplicationController
  before_action :require_supervisor_or_admin, only: %i[new edit create update destroy import import_upload]

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

  def export_download
    @financing_sources = FinancingSource.order(name: :asc)
    date = Time.now.strftime('%Y-%m-%d')
    render xlsx: 'export', disposition: 'attachment', filename: "Export surse de finanțare #{date}.xlsx"
  end

  def import; end

  def import_upload
    uploaded_file = params.require(:file)
    spreadsheet = Roo::Spreadsheet.open(uploaded_file)
    sheet = spreadsheet.sheet(0)

    total_count = 0
    FinancingSource.transaction do
      (2..sheet.last_row).each do |row_index|
        row = sheet.row row_index

        name = row[0].strip

        financing_source = FinancingSource.find_or_initialize_by(name:)
        financing_source.import_code = row[1]&.strip || ''

        raise ImportError.new(row_index, financing_source.errors.full_messages.join(', ')) unless financing_source.save

        total_count += 1
      end
    end

    flash[:notice] = "S-au importat/actualizat cu succes #{total_count} surse de finanțare!"
    redirect_to financing_sources_path

  rescue ImportError => e
    flash.now[:alert] = e.to_s
    render :import
  end

  private

  def financing_source_params
    params.require(:financing_source).permit(:name, :import_code)
  end
end
