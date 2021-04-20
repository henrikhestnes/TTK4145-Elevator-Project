# Elevator Project - TTK4145: Real time programming

## General description
This project is an implementation of an elevator system running `n` elevators across `m` floors, using Elixir. The implementation uses message passing, through use of the following language native OTP behaviours and modules:
- [GenServer](https://hexdocs.pm/elixir/GenServer.html)
- [GenStateMachine](https://hexdocs.pm/gen_state_machine/GenStateMachine.html)
- [Task](https://hexdocs.pm/elixir/Task.html)
- [Agent](https://hexdocs.pm/elixir/Agent.html)
- [Supervisor](https://hexdocs.pm/elixir/Supervisor.html)
- [Process](https://hexdocs.pm/elixir/Process.html)
- [Node](https://hexdocs.pm/elixir/Node.html)

## Modules
The system is divided into the following modules:
- `ElevatorOperator` for running the elevator finite state machine.
    - `ElevatorOperator.DoorTimer` for timing closing of the elevator door.
- `Network` for establishing and maintaining connection to the node cluster.
    - `Network.Listen` for receiving broadcasts with names of other nodes.
    - `Network.Broadcast` for broadcasting own node name.
    - `Network.ConnectionCheck` for checking if the node is connected to the cluster, and requesting backup whenever it becomes connected.
- `Orders` for keeping track of all orders in the cluster.
- `OrderAssigner` for deciding which elevator is best fit to handle an incoming order.
- `OrderDistributor` for distributing new assignments and comleted handling of orders to the rest of the cluster.
- `Watchdog` for reinjecting orders if they are not handled within a set amount of time.
- `Driver` for communicating with the elevator hardware.
- `InputPoller` for polling the various hardware sensors.

Additionally, different modules are supervised by different Supervisors. These Supervisors are responsible for restrating modules if the terminate due to some error.

## Documentation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elevator_project` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elevator_project, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elevator_project](https://hexdocs.pm/elevator_project).

