# frozen_string_literal: true

class PaymentTypesController < ApplicationController
  before_action :require_supervisor_or_admin, only: %i[new edit create update destroy import import_upload]

  def index
    @payment_types = PaymentType.order(name: :asc)
  end

  def new
    @payment_type = PaymentType.new
  end

  def edit
    payment_type_id = params.require(:id)
    @payment_type = PaymentType.find(payment_type_id)
  end

  def create
    @payment_type = PaymentType.new payment_type_params

    successfully_saved = false
    PaymentType.transaction do
      successfully_saved = @payment_type.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :payment_types,
          target_object_id: @payment_type.id
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost salvat cu succes un nou tip de plată cu denumirea '#{@payment_type.name}'"
      redirect_to payment_types_path
    else
      flash[:alert] = 'Nu s-a putut salva noul tip de plată. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    payment_type_id = params.require(:id)
    @payment_type = PaymentType.find(payment_type_id)

    @payment_type.assign_attributes payment_type_params

    successfully_saved = false
    PaymentType.transaction do
      successfully_saved = @payment_type.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :payment_types,
          target_object_id: @payment_type.id,
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost actualizat cu succes tipul de plată cu denumirea '#{@payment_type.name}'"
      redirect_to payment_types_path
    else
      flash[:alert] = 'Nu s-au putut salva modificările la tipurile de plată. Verificați erorile și încercați din nou.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    payment_type_id = params.require(:id)
    @payment_type = PaymentType.find(payment_type_id)

    successfully_deleted = false
    PaymentType.transaction do
      successfully_deleted = @payment_type.destroy

      if successfully_deleted
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :delete,
          target_table: :payment_types,
          target_object_id: @payment_type.id,
        )
      end
    end

    if successfully_deleted
      flash[:notice] = "A fost șters cu succes tipul de plată cu denumirea '#{@payment_type.name}'"
    else
      flash[:alert] = "Nu s-a putut șterge tipul de plată: #{@payment_type.errors.full_messages.join(', ')}."
    end

    redirect_to payment_types_path
  end

  def export_download
    @payment_types = PaymentType.order(name: :asc)
    date = Time.current.strftime('%Y-%m-%d')
    render xlsx: 'export', disposition: 'attachment', filename: "Export tipuri de plăți #{date}.xlsx"
  end

  def import; end

  def import_upload
    uploaded_file = params.require(:file)
    spreadsheet = Roo::Spreadsheet.open(uploaded_file)
    sheet = spreadsheet.sheet(0)

    total_count = 0
    PaymentType.transaction do
      (2..sheet.last_row).each do |row_index|
        row = sheet.row row_index

        name = row[0].strip

        payment_type = PaymentType.find_or_initialize_by(name:)

        unless payment_type.save
          raise ImportError.new(row_index, payment_type.errors.full_messages.join(', '))
        end

        total_count += 1
      end
    end

    flash[:notice] = "S-au importat/actualizat cu succes #{total_count} tipuri de plăți!"
    redirect_to payment_types_path

  rescue ImportError => e
    flash.now[:alert] = e.to_s
    return render :import
  end

  private

  def payment_type_params
    params.require(:payment_type).permit(:name)
  end
end
