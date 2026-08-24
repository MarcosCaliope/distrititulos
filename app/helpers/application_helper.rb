module ApplicationHelper
  def formatar_data(data)
    data&.strftime("%d/%m/%Y")
  end

  def formatar_data_hora(data)
    data&.strftime("%d/%m/%Y %H:%M")
  end
end
