defmodule TaxiBeWeb.BookingController do
  use TaxiBeWeb, :controller
  alias TaxiBeWeb.TaxiAllocationJob

  def create(conn, req) do
    booking_id = UUID.uuid1()

    TaxiAllocationJob.start_link(
      req |> Map.put("booking_id", booking_id),
      String.to_atom(booking_id)
    )

    conn
    |> put_resp_header("Location", "/api/bookings/" <> booking_id)
    |> put_status(:created)
    |> json(%{msg: "Estamos buscando a un colaborador para servirte"})
  end

  def update(conn, %{"action" => "accept", "username" => username, "id" => id} = req) do
    GenServer.cast(String.to_atom(id), {:do_accept, req})
    IO.inspect("'#{username}' is accepting a booking request")
    json(conn, %{msg: "We will process your acceptance"})
  end

  def update(conn, %{"action" => "reject", "username" => username, "id" => _id}) do
    IO.inspect("'#{username}' is rejecting a booking request")
    json(conn, %{msg: "We will process your rejection"})
  end

  def update(conn, %{"action" => "cancel", "username" => username, "id" => _id}) do
    IO.inspect("'#{username}' is cancelling a booking request")
    json(conn, %{msg: "We will process your cancelation"})
  end
end
