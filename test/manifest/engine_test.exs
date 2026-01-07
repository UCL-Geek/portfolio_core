defmodule PortfolioCore.Manifest.EngineTest do
  use PortfolioCore.SupertesterCase, async: false

  alias PortfolioCore.Manifest.Engine

  @test_manifest """
  version: "1.0"
  environment: test
  adapters:
    vector_store:
      adapter: PortfolioCore.Mocks.VectorStore
      config:
        dimensions: 1536
  """

  setup do
    # Write temp manifest file
    path = Path.join(System.tmp_dir!(), "test_manifest_#{:rand.uniform(10000)}.yml")
    File.write!(path, @test_manifest)

    on_exit(fn -> File.rm(path) end)

    {:ok, path: path}
  end

  test "loads manifest from file", %{path: path} do
    {:ok, pid} = Engine.start_link(manifest_path: path, name: :test_engine)

    manifest = Engine.get_manifest(:test_engine)

    assert manifest[:version] == "1.0"
    assert manifest[:environment] == :test

    GenServer.stop(pid)
  end

  test "gets adapter for port", %{path: path} do
    {:ok, pid} = Engine.start_link(manifest_path: path, name: :test_engine_2)

    {module, config} = Engine.get_adapter(:vector_store, :test_engine_2)

    assert module == PortfolioCore.Mocks.VectorStore
    assert config[:dimensions] == 1536

    GenServer.stop(pid)
  end

  test "returns nil for unregistered port", %{path: path} do
    {:ok, pid} = Engine.start_link(manifest_path: path, name: :test_engine_3)

    assert nil == Engine.get_adapter(:unknown_port, :test_engine_3)

    GenServer.stop(pid)
  end

  test "reloads manifest", %{path: path} do
    {:ok, pid} = Engine.start_link(manifest_path: path, name: :test_engine_4)

    # Update the file
    updated_manifest = """
    version: "2.0"
    environment: test
    adapters:
      vector_store:
        adapter: PortfolioCore.Mocks.VectorStore
        config:
          dimensions: 3072
    """

    File.write!(path, updated_manifest)

    assert :ok == Engine.reload(:test_engine_4)

    manifest = Engine.get_manifest(:test_engine_4)
    assert manifest[:version] == "2.0"

    {_module, config} = Engine.get_adapter(:vector_store, :test_engine_4)
    assert config[:dimensions] == 3072

    GenServer.stop(pid)
  end

  test "expands environment variables" do
    System.put_env("TEST_API_KEY", "secret123")

    manifest = """
    version: "1.0"
    environment: test
    adapters:
      embedder:
        adapter: PortfolioCore.Mocks.Embedder
        config:
          api_key: ${TEST_API_KEY}
    """

    path = Path.join(System.tmp_dir!(), "env_manifest.yml")
    File.write!(path, manifest)

    {:ok, pid} = Engine.start_link(manifest_path: path, name: :env_engine)

    {_module, config} = Engine.get_adapter(:embedder, :env_engine)
    assert config[:api_key] == "secret123"

    GenServer.stop(pid)
    File.rm(path)
    System.delete_env("TEST_API_KEY")
  end

  test "starts without manifest path" do
    {:ok, pid} = Engine.start_link(name: :no_manifest_engine)

    assert nil == Engine.get_manifest(:no_manifest_engine)

    GenServer.stop(pid)
  end

  test "reload returns error when no manifest path" do
    {:ok, pid} = Engine.start_link(name: :no_path_engine)

    assert {:error, :no_manifest_path} == Engine.reload(:no_path_engine)

    GenServer.stop(pid)
  end

  test "load function loads new manifest from path" do
    {:ok, pid} = Engine.start_link(name: :load_test_engine)

    manifest = """
    version: "1.0"
    environment: test
    adapters:
      vector_store:
        adapter: PortfolioCore.Mocks.VectorStore
        config:
          dimensions: 512
    """

    path = Path.join(System.tmp_dir!(), "load_manifest_#{:rand.uniform(10000)}.yml")
    File.write!(path, manifest)

    assert :ok = Engine.load(path, :load_test_engine)

    loaded = Engine.get_manifest(:load_test_engine)
    assert loaded[:version] == "1.0"

    {module, config} = Engine.get_adapter(:vector_store, :load_test_engine)
    assert module == PortfolioCore.Mocks.VectorStore
    assert config[:dimensions] == 512

    GenServer.stop(pid)
    File.rm(path)
  end

  test "fails to start with invalid manifest" do
    path = Path.join(System.tmp_dir!(), "invalid_manifest_#{:rand.uniform(10000)}.yml")
    File.write!(path, "invalid: yaml: content:")

    Process.flag(:trap_exit, true)

    assert {:error, {:manifest_error, _}} =
             Engine.start_link(manifest_path: path, name: :invalid_engine)

    Process.flag(:trap_exit, false)
    File.rm(path)
  end

  test "handles missing required adapter" do
    manifest = """
    version: "1.0"
    environment: test
    adapters:
      vector_store:
        config:
          dimensions: 1536
    """

    path = Path.join(System.tmp_dir!(), "no_adapter_#{:rand.uniform(10000)}.yml")
    File.write!(path, manifest)

    Process.flag(:trap_exit, true)

    assert {:error, {:manifest_error, {:vector_store, :adapter_not_specified}}} =
             Engine.start_link(manifest_path: path, name: :no_adapter_engine)

    Process.flag(:trap_exit, false)
    File.rm(path)
  end

  test "handles module not found error" do
    manifest = """
    version: "1.0"
    environment: test
    adapters:
      vector_store:
        adapter: NonExistentModule.ThatDoesNotExist
        config:
          dimensions: 1536
    """

    path = Path.join(System.tmp_dir!(), "bad_module_#{:rand.uniform(10000)}.yml")
    File.write!(path, manifest)

    Process.flag(:trap_exit, true)

    assert {:error, {:manifest_error, {:vector_store, {:module_not_found, _}}}} =
             Engine.start_link(manifest_path: path, name: :bad_module_engine)

    Process.flag(:trap_exit, false)
    File.rm(path)
  end
end
