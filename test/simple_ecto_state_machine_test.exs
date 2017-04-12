defmodule SimpleEctoStateMachineTest do
  import ExUnit.CaptureLog
  import Ecto.Changeset
  use ExUnit.Case

  @moduledoc """
  Unit tests for SimpleEctoStateMachine
  """

  defmodule TestModule do
    use Ecto.Model
    require Logger

    @moduledoc """
    Dummy module that uses Ecto.Model for tests.
    """

    def test_success_callback(_) do
      Logger.info("Success!")
    end

    def test_error_callback(_) do
      Logger.error("Something went wrong.")
    end

    use SimpleEctoStateMachine,
      field: :status,
      transitions: [
        %{
          from: "status_a",
          to: ["status_b"],
          status_b_callback: &__MODULE__.test_success_callback/1,
          state_machine_error_callback: &__MODULE__.test_error_callback/1
        },
        %{from: "status_b", to: ["status_c"]}
      ]

    schema "test" do
      field :status, :string
      field :name, :string
    end
  end

  describe "A status update to a model using SimpleEctoStateMachine" do
    test "succeeds when the transition is valid" do
      assert valid_update.valid?
    end

    test "fails when the transition is invalid" do
      refute invalid_update.valid?
    end

    test "runs the adequate callback when transition is valid" do
      assert capture_log(fn -> valid_update end) =~ "Success!"
    end

    test "runs the error callback when transition is invalid" do
      assert capture_log(fn -> invalid_update end) =~ "Something went wrong."
    end

    test "succeeds when the change is not related to the state machine" do
      changeset = %TestModule{name: "unrelated"}
        |> cast(%{name: "changed"}, [:name], [])
        |> TestModule.validate_status_update
      assert changeset.valid?
    end

    test "succeeds when the transition has no callback related" do
      changeset = %TestModule{status: "status_b"}
        |> cast(%{status: "status_c"}, [:status], [])
        |> TestModule.validate_status_update
      assert changeset.valid?
    end
  end

  defp valid_update do
    %TestModule{status: "status_a"}
      |> cast(%{status: "status_b"}, [:status], [])
      |> TestModule.validate_status_update
  end

  defp invalid_update do
    %TestModule{status: "status_a"}
      |> cast(%{status: "status_c"}, [:status], [])
      |> TestModule.validate_status_update
  end
end
