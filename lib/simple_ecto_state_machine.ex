defmodule SimpleEctoStateMachine do
  import Ecto.Changeset

  @moduledoc """
  A simple state machine for Ecto Models. It works on the changeset of the
  model when the changeset is updated. When a state machine is `use`d inside
  and Ecto model, a function of the form `validate_{field}_update(changeset)` is
  defined in the model, ready to test the changeset when is updated.

  ```
    defmodule MyModule do
      use Ecto.Model

      schema "my_module" do
        field :status
      end

      use SimpleEctoStateMachine,
        field: :status,
        transitions: [
          %{from: "status_a".  to: ["status_b, "status_c"]},
          %{from: "status_b", to: ["status_c"]}
        ]

      def changeset(model, params \\ :empty) do
        model
          |> cast(params, ["status"], [])
          |> validate_status_update # <= Function defined by
                                    # SimpleEctoStateMachine at compile time.
      end
    end
  ```

  Callbacks can be defined to be called in the case of success or error.
  Callbacks can be provided per destination. In case of a successful transition
  the callback with the form `{to}_callback` will be called. The error callback
  must be named `state_machine_error_callback` and will be called if a
  transition with a valid `from` is provided but the new value does not match
  any of the valid `to`s, i.e:

  ```
    def success_callback(_changeset) do
      IO.puts "Valid transition!"
    end

    def error_callback(_changeset) do
      IO.puts "Invalid transition."
    end

    use SimpleEctoStateMachine,
      field: status
      transitions: [
        %{
          from: "status_a",
          to: ["status_b, status_c"],
          status_a_callback: &__MODULE__.success_callback/1,
          status_b_callback: &__MODULE__.success_callback/1,
          error_callback: &__MODULE__.error.callback/1
        }
      ]
  ```

  Make sure to only define one transition per `from`, since repeating `from`s
  lead to an error in the state machine. All possible transitions for a `from`
  must be defined in a single transition.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      field = Keyword.get(opts, :field)
      transitions = Keyword.get(opts, :transitions)
      def unquote(:"validate_#{field}_update")(changeset, arg) do
        field = unquote(field)
        transitions = unquote(Macro.escape(transitions))
        parsed_transitions = SimpleEctoStateMachine.parse_transitions(transitions)
        from = Map.from_struct(changeset.model)[field]
        to = changeset.changes[field]
        if is_nil(to) || to in (parsed_transitions[from]) do
          SimpleEctoStateMachine.valid_transition(from, to, transitions, changeset, arg)
        else
          SimpleEctoStateMachine.invalid_transition(from, to, field, transitions, changeset, arg)
        end
      end
      def unquote(:"validate_#{field}_update")(changeset) do
        field = unquote(field)
        transitions = unquote(Macro.escape(transitions))
        parsed_transitions = SimpleEctoStateMachine.parse_transitions(transitions)
        from = Map.from_struct(changeset.model)[field]
        to = changeset.changes[field]
        if is_nil(to) || to in (parsed_transitions[from]) do
          SimpleEctoStateMachine.valid_transition(from, to, transitions, changeset)
        else
          SimpleEctoStateMachine.invalid_transition(from, to, field, transitions, changeset)
        end
      end
    end
  end

  @doc false
  def valid_transition(_, nil, _, changeset, _) do
    changeset
  end
  def valid_transition(from, to, transitions, changeset, arg) do
    execute_callback(from, to, transitions, changeset, arg)
    changeset
  end
  def valid_transition(_, nil, _, changeset) do
    changeset
  end
  def valid_transition(from, to, transitions, changeset) do
    execute_callback(from, to, transitions, changeset)
    changeset
  end

  @doc false
  def invalid_transition(from, to, field, transitions, changeset, arg) do
    execute_callback(from, "state_machine_error", transitions, changeset, arg)
    message = """
    Invalid update for #{field}. Wanted to transition from #{from} to #{to} for
    the field #{field}.
    """
    add_error(changeset, field, message)
  end

  def invalid_transition(from, to, field, transitions, changeset) do
    execute_callback(from, "state_machine_error", transitions, changeset)
    message = """
    Invalid update for #{field}. Wanted to transition from #{from} to #{to} for
    the field #{field}.
    """
    add_error(changeset, field, message)
  end

  @doc false
  def get_transition(transitions, from) do
    hd(Enum.filter(transitions, fn(t) -> t.from == from end))
  end

  @doc false
  def execute_callback(from, to, transitions, changeset, arg) do
    case get_callback(from, to, transitions) do
      nil -> :ok
      callback -> callback.(changeset, arg)
    end
  end

  @doc false
  def execute_callback(from, to, transitions, changeset) do
    case get_callback(from, to, transitions) do
      nil -> :ok
      callback -> callback.(changeset)
    end
  end

  def get_callback(from, to, transitions) do
    transitions
      |> get_transition(from)
      |> Map.get(:"#{String.downcase(to)}_callback")
  end

  @doc """
  Translates the given `transitions` to a map. For example:
  ```
  transitions = [
    %{from: "status_a", to: ["status_b"]},
    %{from: "status_b", to: ["status_a", "status_c"}]
  ]
  parsed_transitions(transitions)
  => %{
    "status_a" => ["status_b"],
    "status_b" => ["status_a", "status_c"]
  }
  ```
  """
  def parse_transitions(transitions) do
    Enum.reduce(transitions, %{}, fn(%{from: from, to: to} = transition, acc) ->
      Map.put(acc, from, to)
    end)
  end
end
