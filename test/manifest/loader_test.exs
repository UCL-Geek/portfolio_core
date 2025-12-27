defmodule PortfolioCore.Manifest.LoaderTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Manifest.Loader

  describe "load/1" do
    setup do
      path = Path.join(System.tmp_dir!(), "test_#{:rand.uniform(10000)}.yml")
      on_exit(fn -> File.rm(path) end)
      {:ok, path: path}
    end

    test "loads valid YAML file", %{path: path} do
      content = """
      version: "1.0"
      environment: dev
      adapters:
        vector_store:
          adapter: MyAdapter
      """

      File.write!(path, content)

      assert {:ok, manifest} = Loader.load(path)
      assert manifest["version"] == "1.0"
      assert manifest["environment"] == "dev"
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = Loader.load("/non/existent/path.yml")
    end

    test "returns error for invalid YAML" do
      path = Path.join(System.tmp_dir!(), "invalid.yml")
      File.write!(path, "invalid: yaml: content: [")

      result = Loader.load(path)
      assert {:error, {:yaml_parse_error, _}} = result

      File.rm(path)
    end
  end

  describe "expand_env_vars/1" do
    setup do
      # Save and restore env vars
      old_val = System.get_env("TEST_VAR")
      System.put_env("TEST_VAR", "test_value")
      System.put_env("ANOTHER_VAR", "another_value")

      on_exit(fn ->
        if old_val, do: System.put_env("TEST_VAR", old_val), else: System.delete_env("TEST_VAR")
        System.delete_env("ANOTHER_VAR")
      end)

      :ok
    end

    test "expands single variable in string" do
      assert {:ok, "test_value"} = Loader.expand_env_vars("${TEST_VAR}")
    end

    test "expands variable with surrounding text" do
      assert {:ok, "prefix_test_value_suffix"} =
               Loader.expand_env_vars("prefix_${TEST_VAR}_suffix")
    end

    test "expands multiple variables" do
      assert {:ok, "test_value and another_value"} =
               Loader.expand_env_vars("${TEST_VAR} and ${ANOTHER_VAR}")
    end

    test "returns error for missing variable" do
      assert {:error, {:missing_env_var, "MISSING_VAR"}} =
               Loader.expand_env_vars("${MISSING_VAR}")
    end

    test "expands variables in nested maps" do
      input = %{
        "outer" => %{
          "inner" => "${TEST_VAR}"
        }
      }

      assert {:ok, %{"outer" => %{"inner" => "test_value"}}} = Loader.expand_env_vars(input)
    end

    test "expands variables in lists" do
      input = ["${TEST_VAR}", "static", "${ANOTHER_VAR}"]

      assert {:ok, ["test_value", "static", "another_value"]} = Loader.expand_env_vars(input)
    end

    test "returns non-string values unchanged" do
      assert {:ok, 42} = Loader.expand_env_vars(42)
      assert {:ok, true} = Loader.expand_env_vars(true)
      assert {:ok, nil} = Loader.expand_env_vars(nil)
    end
  end

  describe "load_string/1" do
    test "parses YAML from string" do
      yaml = """
      key: value
      nested:
        inner: data
      """

      assert {:ok, %{"key" => "value", "nested" => %{"inner" => "data"}}} =
               Loader.load_string(yaml)
    end

    test "returns error for invalid YAML" do
      # Use YAML that fails parsing quickly
      assert {:error, {:yaml_parse_error, _}} = Loader.load_string("invalid: yaml: value:")
    end
  end

  describe "load!/1" do
    setup do
      path = Path.join(System.tmp_dir!(), "load_bang_#{:rand.uniform(10000)}.yml")
      on_exit(fn -> File.rm(path) end)
      {:ok, path: path}
    end

    test "returns manifest on success", %{path: path} do
      File.write!(path, "key: value")
      manifest = Loader.load!(path)
      assert manifest["key"] == "value"
    end

    test "raises for missing file" do
      assert_raise RuntimeError, ~r/Failed to load manifest/, fn ->
        Loader.load!("/non/existent/file.yml")
      end
    end

    test "raises for missing env var" do
      path = Path.join(System.tmp_dir!(), "env_error.yml")
      File.write!(path, "key: ${UNDEFINED_VAR_XXXX}")

      assert_raise RuntimeError, ~r/Missing environment variable/, fn ->
        Loader.load!(path)
      end

      File.rm(path)
    end
  end

  describe "expand_env_vars error propagation" do
    test "propagates error from nested map" do
      input = %{"key" => "${NONEXISTENT_VAR_ZZZZZ}"}
      assert {:error, {:missing_env_var, _}} = Loader.expand_env_vars(input)
    end

    test "propagates error from list" do
      input = ["static", "${NONEXISTENT_VAR_YYYY}"]
      assert {:error, {:missing_env_var, _}} = Loader.expand_env_vars(input)
    end

    test "returns string without vars unchanged" do
      assert {:ok, "no variables here"} = Loader.expand_env_vars("no variables here")
    end
  end
end
