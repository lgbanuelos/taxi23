defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    IO.inspect(request)
    Process.send(self(), :step1, [:nosuspend])
    {:ok, %{request: request}}
  end

  def handle_info(:step1, %{request: request} = state) do
    upperPath = Task.async(fn ->
      compute_ride_fare(request)
      |> notify_customer_ride_fare()
      end)

    taxis = select_candidate_taxis(request)
    Task.await(upperPath)

    state = exec_step2(state, taxis)

    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    state = exec_step3(state)
    {:noreply, state}
  end

  def handle_info({:step2, response}, state) do

    {:noreply, state}
  end

  def handle_cast({:do_accept, response}, state) do
    IO.inspect(response)
    Process.send(self(), {:step2, response}, [:nosuspend])
    {:noreply, state}
  end

  def handle_cast({:do_reject, response}, state) do
    state = exec_step3(state)
    {:noreply, state}
  end


  def exec_step2(%{request: request} = state, taxis) do
    taxi = Enum.take_random(taxis, 1) |> hd()

    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request
    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_request",
       %{
         msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
         bookingId: booking_id
        })

    time = Process.send_after(self(), :timeout, 30_000)
    state |> Map.put(:contacted_taxis, [taxi]) |> Map.put(:candidate_taxis, taxis) |> Map.put(:timer, time)
  end

  def exec_step3(%{contacted_taxis: contacted, candidate_taxis: candidate} = state) do
    remaining = Enum.filter(candidate, fn t -> t not in contacted end)
    IO.inspect(remaining)

    state
  end

  def compute_ride_fare(request) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
     } = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
    {distance, _duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, Float.ceil(distance/70)}
  end

  def notify_customer_ride_fare({request, fare}) do
    %{"username" => customer} = request
   TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare}"})
  end

  def select_candidate_taxis(%{"pickup_address" => _pickup_address}) do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end
end
