defmodule PortfolioCore.TelemetryTest do
  use ExUnit.Case

  alias PortfolioCore.Telemetry

  defmodule TestHandler do
    @moduledoc false
    def handle_event(event, measurements, metadata, %{parent: parent}) do
      send(parent, {:telemetry, event, measurements, metadata})
    end
  end

  describe "events/0" do
    test "returns list of all events" do
      events = Telemetry.events()

      assert is_list(events)
      # Legacy events
      assert [:portfolio_core, :manifest, :loaded] in events
      assert [:portfolio_core, :adapter, :call, :start] in events
      assert [:portfolio_core, :registry, :register] in events
      assert [:portfolio_core, :router, :route, :start] in events
      assert [:portfolio_core, :cache, :get, :hit] in events
      assert [:portfolio_core, :agent, :run, :start] in events
      # New portfolio events
      assert [:portfolio, :embedder, :embed, :start] in events
      assert [:portfolio, :vector_store, :search, :start] in events
      assert [:portfolio, :llm, :complete, :start] in events
      assert [:portfolio, :rag, :rewrite, :start] in events
      assert [:portfolio, :evaluation, :run, :start] in events
    end
  end

  describe "events_for/1" do
    test "returns embedder events" do
      events = Telemetry.events_for(:embedder)

      assert [:portfolio, :embedder, :embed, :start] in events
      assert [:portfolio, :embedder, :embed, :stop] in events
      assert [:portfolio, :embedder, :embed, :exception] in events
      assert [:portfolio, :embedder, :embed_batch, :start] in events
    end

    test "returns vector_store events" do
      events = Telemetry.events_for(:vector_store)

      assert [:portfolio, :vector_store, :search, :start] in events
      assert [:portfolio, :vector_store, :insert, :start] in events
    end

    test "returns llm events" do
      events = Telemetry.events_for(:llm)

      assert [:portfolio, :llm, :complete, :start] in events
      assert [:portfolio, :llm, :complete, :stop] in events
      assert [:portfolio, :llm, :complete, :exception] in events
    end

    test "returns rag events" do
      events = Telemetry.events_for(:rag)

      assert [:portfolio, :rag, :rewrite, :start] in events
      assert [:portfolio, :rag, :expand, :start] in events
      assert [:portfolio, :rag, :decompose, :start] in events
      assert [:portfolio, :rag, :select, :start] in events
      assert [:portfolio, :rag, :search, :start] in events
      assert [:portfolio, :rag, :rerank, :start] in events
      assert [:portfolio, :rag, :answer, :start] in events
      assert [:portfolio, :rag, :self_correct, :start] in events
    end

    test "returns evaluation events" do
      events = Telemetry.events_for(:evaluation)

      assert [:portfolio, :evaluation, :run, :start] in events
      assert [:portfolio, :evaluation, :test_case, :start] in events
    end

    test "returns empty list for unknown component" do
      assert Telemetry.events_for(:unknown) == []
    end
  end

  describe "span/3" do
    test "emits start and stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-span-new-#{inspect(ref)}",
        [
          [:portfolio, :test, :operation, :start],
          [:portfolio, :test, :operation, :stop]
        ],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      result =
        Telemetry.span([:portfolio, :test, :operation], %{key: "value"}, fn ->
          {:ok, "span result"}
        end)

      assert result == {:ok, "span result"}

      assert_receive {:telemetry, [:portfolio, :test, :operation, :start], _, start_meta}
      assert start_meta[:key] == "value"

      assert_receive {:telemetry, [:portfolio, :test, :operation, :stop], stop_measurements, _}
      assert stop_measurements[:duration] > 0

      :telemetry.detach("test-span-new-#{inspect(ref)}")
    end

    test "emits exception event on error" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-span-exception-#{inspect(ref)}",
        [
          [:portfolio, :test, :fail, :start],
          [:portfolio, :test, :fail, :exception]
        ],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      assert_raise RuntimeError, fn ->
        Telemetry.span([:portfolio, :test, :fail], %{}, fn ->
          raise "test error"
        end)
      end

      assert_receive {:telemetry, [:portfolio, :test, :fail, :start], _, _}
      assert_receive {:telemetry, [:portfolio, :test, :fail, :exception], measurements, meta}
      assert measurements[:duration] > 0
      assert meta[:kind] == :error
      assert %RuntimeError{message: "test error"} = meta[:reason]

      :telemetry.detach("test-span-exception-#{inspect(ref)}")
    end
  end

  describe "emit/3" do
    test "emits telemetry event" do
      ref = make_ref()

      :telemetry.attach(
        "test-emit-#{inspect(ref)}",
        [:portfolio_core, :test_event],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      assert :ok = Telemetry.emit([:test_event], %{count: 1}, %{key: "value"})

      assert_receive {:telemetry, [:portfolio_core, :test_event], %{count: 1}, %{key: "value"}}

      :telemetry.detach("test-emit-#{inspect(ref)}")
    end
  end

  describe "measure/3" do
    test "measures function execution and emits telemetry" do
      ref = make_ref()

      :telemetry.attach(
        "test-measure-#{inspect(ref)}",
        [:portfolio_core, :measured_op],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      result =
        Telemetry.measure([:measured_op], %{op: "test"}, fn ->
          :timer.sleep(10)
          {:ok, "result"}
        end)

      assert result == {:ok, "result"}

      assert_receive {:telemetry, [:portfolio_core, :measured_op], measurements, metadata}
      assert measurements[:duration] > 0
      assert metadata[:status] == :ok
      assert metadata[:op] == "test"

      :telemetry.detach("test-measure-#{inspect(ref)}")
    end

    test "handles exceptions and emits telemetry" do
      ref = make_ref()

      :telemetry.attach(
        "test-measure-error-#{inspect(ref)}",
        [:portfolio_core, :error_op],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      assert_raise RuntimeError, fn ->
        Telemetry.measure([:error_op], %{op: "failing"}, fn ->
          raise "test error"
        end)
      end

      assert_receive {:telemetry, [:portfolio_core, :error_op], measurements, metadata}
      assert measurements[:duration] > 0
      assert metadata[:status] == :error
      assert metadata[:error] == "test error"

      :telemetry.detach("test-measure-error-#{inspect(ref)}")
    end
  end

  describe "with_span macro" do
    test "emits start and stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-span-#{inspect(ref)}",
        [
          [:portfolio_core, :span_test, :start],
          [:portfolio_core, :span_test, :stop]
        ],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      require Telemetry

      result =
        Telemetry.with_span [:span_test], %{key: "value"} do
          {:ok, "span result"}
        end

      assert result == {:ok, "span result"}

      assert_receive {:telemetry, [:portfolio_core, :span_test, :start], _, start_meta}
      assert start_meta[:key] == "value"

      assert_receive {:telemetry, [:portfolio_core, :span_test, :stop], stop_measurements, _}
      assert stop_measurements[:duration] > 0

      :telemetry.detach("test-span-#{inspect(ref)}")
    end

    test "emits exception event on error" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-span-error-#{inspect(ref)}",
        [
          [:portfolio_core, :error_span, :start],
          [:portfolio_core, :error_span, :exception]
        ],
        &TestHandler.handle_event/4,
        %{parent: self()}
      )

      require Telemetry

      assert_raise RuntimeError, fn ->
        Telemetry.with_span [:error_span] do
          raise "span error"
        end
      end

      assert_receive {:telemetry, [:portfolio_core, :error_span, :start], _, _}
      assert_receive {:telemetry, [:portfolio_core, :error_span, :exception], _, meta}
      assert meta[:kind] == :error
      assert meta[:reason].__struct__ == RuntimeError

      :telemetry.detach("test-span-error-#{inspect(ref)}")
    end
  end
end
